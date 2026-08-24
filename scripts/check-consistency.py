#!/usr/bin/env python3
"""
Consistency / integrity checker for the gitops repo.

Single source of truth = the set of hosts Traefik actually routes:
  * explicit ``Host(_`host`.dominiksiejak.pl`)`` rules in stacks/*/compose.yaml traefik router labels
  * the default-rule host ``{router}.dominiksiejak.pl`` for an enabled router that declares
    no explicit rule label (mirrors Traefik ``defaultRule``)
  * file routers in stacks/traefik/dynamic.yaml

That truth set is compared against every independent consumer meant to mirror "all deployed
apps", and — for safe infra YAML — auto-repaired:

  Invariant 1  Grafana/blackbox monitors ALL Traefik hosts
               -> stacks/monitoring/victoria-metrics/promscrape.yaml  (AUTO-FIXED)
  Invariant 2  auth.dominiksiejak.pl shows every app (oauth2 / proxy / dashboard / LDAP)
               -> terraform/authentik/locals.tf                        (REPORT-ONLY, terraform)
  Invariant 3  homepage.dominiksiejak.pl shows every app and uses a built-in widget where one
               exists -> stacks/homepage/config/services.yaml          (AUTO-FIXED)

Secondary, report-only views: gatus config and README host mentions.

Usage:
  python3 scripts/check-consistency.py [--dry-run] [--fix] [--json] [--repo-path PATH]

Exit code:
  0  no consistency errors (dry-run found nothing, or --fix cleared them)
  1  a consistency ERROR remains (drift, or an un-auto-fixable one: terraform / README)
"""

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DOMAIN = 'dominiksiejak.pl'

# Hosts that are legitimately routed (and may be tracked by blackbox/homepage) but are
# defined OUTSIDE this repo's stacks/ (e.g. the Portainer-managed portainer container).
EXTERNAL_ROUTED = {'portainer'}

# Hosts the homepage deliberately surfaces over a LAN/hypervisor IP instead of the
# publicly-proxied *.dominiksiejak.pl hostname, so absence in services.yaml is correct.
HOMEPAGE_LAN_IP = {'nas', 'proxmox', 'router', 'adguard'}

# Authentik app slugs that have no HTTP Traefik host by design (LDAP) + external apps.
AUTH_NO_HTTP_ROUTE = {'ldap'} | {'routeros'} | EXTERNAL_ROUTED

# Authentik apps the operator intentionally keeps as dashboard-only / hostname-renamed,
# so "no matching Traefik route" is expected — still reported, never a blocking error.
# AUTH_OK_NO_ROUTE: slug/host names that are not Traefik hosts (OIDC-only, LDAP, aliases)
AUTH_OK_NO_ROUTE = {'esphome', 'watchyourlan', 'n8n-gateway'}

# Homepage hosts that intentionally have no Authentik app (native auth, basicAuth, OPDS, IdP).
HOMEPAGE_NO_AUTH = {'auth', 'calibre-api', 'lan', 'opencode', 'unifi'}
HOST_RE = re.compile(r'https?://([a-z0-9][a-z0-9-]*)\.' + re.escape(DOMAIN) + r'(?:/|["\s]|$)')
RULE_LABEL_RE = re.compile(r'traefik\.http\.routers\.([a-z0-9_-]+)\.rule:\s*(.+)')
ROUTER_RE = re.compile(r'traefik\.http\.routers\.([a-z0-9_-]+)\.')

HOST_RULE_RE = re.compile(r'Host\(\s*`([a-z0-9][a-z0-9-]*)\.' + re.escape(DOMAIN) + r'`')

GC = []  # (verb, detail) applied → for change summary

CHANGES = []
def note(verb, detail):
    CHANGES.append((verb, detail))


# ---------------------------------------------------------------------------
# Source of truth: Traefik-routed hosts
# ---------------------------------------------------------------------------
def compose_rules():
    rules = {}
    for f in sorted((REPO / 'stacks').glob('*/compose.yaml')):
        for m in RULE_LABEL_RE.finditer(f.read_text()):
            name, rule = m.group(1), m.group(2).strip().strip('"')
            rules.setdefault(name, rule)
    return rules


def traefik_hosts():
    import yaml
    hosts = set()

    # 1) explicit Host() rules anywhere (compose labels + dynamic.yaml)
    for f in sorted((REPO / 'stacks').glob('*/compose.yaml')):
        for name, rule in compose_rules().items():
            m = HOST_RULE_RE.search(rule)
            if m:
                hosts.add(m.group(1))

    # 2) default-rule host for services exposed to Traefik whose router defines NO
    #    explicit Host() rule. Traefik defaultRule = `{ContainerName}.dominiksiejak.pl`,
    #    so the host is the container_name (e.g. hass-timemachine, not the label name).
    for f in sorted((REPO / 'stacks').glob('*/compose.yaml')):
        try:
            doc = yaml.safe_load(f.read_text())
        except Exception:
            continue
        for svc, spec in (doc.get('services', {}) or {}).items():
            spec = spec or {}
            labels = spec.get('labels', {}) or {}
            if isinstance(labels, list):
                labels = {kv.split('=', 1)[0]: kv.split('=', 1)[1] if '=' in kv else ''
                          for kv in labels if isinstance(kv, str)}
            exposed = any('traefik.http.routers' in k for k in labels) or \
                      str(labels.get('traefik.enable', '')).lower() == 'true'
            if not exposed:
                continue
            # if any router label for this service has an explicit rule, the container
            # is served under that host — not a bare default-rule host.
            has_rule = any(k.endswith('.rule') and ('Host(' in v or 'HostRegexp' in v)
                           for k, v in labels.items())
            if has_rule:
                continue
            hosts.add(spec.get('container_name', svc))

    # 3) file routers in dynamic.yaml (rules are Host(`nas.dominik`) — no https:// scheme)
    dyn = REPO / 'stacks' / 'traefik' / 'dynamic.yaml'
    if dyn.exists():
        hosts |= {m.group(1) for m in HOST_RULE_RE.finditer(dyn.read_text())}

    # drop partial names that slipped in (e.g. 'dominiksiejak' if domain used bare)
    hosts |= EXTERNAL_ROUTED  # routed, but configured outside this repo (Portainer-managed)
    return {h for h in hosts if h != DOMAIN}


# ---------------------------------------------------------------------------
# Derived consumer sets
# ---------------------------------------------------------------------------
def blackbox_hosts():
    text = (REPO / 'stacks' / 'monitoring' / 'victoria-metrics' / 'promscrape.yaml').read_text()
    hosts = {m.group(1) for m in HOST_RE.finditer(text)}
    hosts |= {m for m in re.findall(r'job_name:\s*blackbox-([a-z0-9-]+)', text)}
    return hosts


def homepage_entries():
    """Return {host: {name, widget}} for services.yaml hrefs on our domain."""
    text = (REPO / 'stacks' / 'homepage' / 'config' / 'services.yaml').read_text()
    host = {}
    lines = text.splitlines()
    for i, ln in enumerate(lines):
        m = re.search(r'href:\s*https?://([a-z0-9][a-z0-9-]*)\.dominiksiejak\.pl', ln)
        if not m:
            continue
        hostname = m.group(1)
        name = None
        for j in range(i, -1, -1):
            s = lines[j].strip()
            if s.startswith('- ') and ':' in s and 'href' not in s and 'widget' not in s:
                name = s[2:].strip().rstrip(':')
                break
        window = '\n'.join(lines[i + 1:i + 10])
        host[hostname] = {
            'name': name or '?',
            'widget': bool(re.search(r'^\s*widget:', window, re.M)),
        }
    return host


def auth_hosts():
    hosts = {m.group(1) for m in HOST_RE.finditer((REPO / 'terraform' / 'authentik' / 'locals.tf').read_text())}
    ldap = (REPO / 'terraform' / 'authentik' / 'ldap.tf').read_text()
    if 'authentik_application' in ldap and 'slug' in ldap:
        hosts.add('ldap')
    return hosts


def gatus_hosts():
    return {m.group(1) for m in HOST_RE.finditer((REPO / 'stacks' / 'gatus' / 'config.yaml').read_text())}


def readme_hosts():
    return {m.group(1) for m in HOST_RE.finditer((REPO / 'README.md').read_text())}


# ---------------------------------------------------------------------------
# Best-effort homepage widget map (placeholder var names)
# ---------------------------------------------------------------------------
HOMEPAGE_WIDGETS = {
    'traefik':     {'type': 'traefik',     'url': 'http://traefik:8080',        'key': 'key',        'var': ''},
    'grafana':     {'type': 'grafana',     'url': 'http://grafana:3000',        'key': 'username',   'var': ''},
    'gatus':       {'type': 'gatus',       'url': 'http://gatus:8080',          'key': '',           'var': ''},
    'authentik':   {'type': 'authentik',   'url': 'http://authentik-server:9000','key': 'key',       'var': 'AUTHENTIK_KEY'},
    'portainer':   {'type': 'portainer',   'url': 'http://portainer:9000',      'key': 'env',        'var': 'PORTAINER_TOKEN'},
    'gitea':       {'type': 'gitea',       'url': 'http://gitea:3000',          'key': 'key',        'var': 'GITEA_TOKEN'},
    'radarr':      {'type': 'radarr',      'url': 'http://radarr:7878',         'key': 'key',        'var': 'RADARR_KEY'},
    'sonarr':      {'type': 'sonarr',      'url': 'http://sonarr:8989',         'key': 'key',        'var': 'SONARR_KEY'},
    'readarr':     {'type': 'readarr',     'url': 'http://readarr:8787',        'key': 'key',        'var': 'READARR_KEY'},
    'bazarr':      {'type': 'bazarr',      'url': 'http://bazarr:6767',         'key': 'key',        'var': 'BAZARR_KEY'},
    'jellyfin':    {'type': 'jellyfin',    'url': 'http://jellyfin:8096',       'key': 'key',        'var': 'JELLYFIN_KEY'},
    'sabnzbd':     {'type': 'sabnzbd',     'url': 'http://gluetun:8085',        'key': 'key',        'var': 'SABNZBD_KEY'},
    'qbittorrent': {'type': 'qbittorrent', 'url': 'http://gluetun:8080',        'key': 'key',        'var': 'QBT_KEY'},
    'dozzle':      {'type': 'dozzle',      'url': 'http://dozzle:8080',         'key': '',           'var': ''},
}
WIDGET_CAPABLE = set(HOMEPAGE_WIDGETS) | {'proxmox', 'synology', 'mikrotik', 'cloudflared', 'adguard', 'watchyourlan', 'homeassistant', 'victoriametrics', 'unifi'}


# ---------------------------------------------------------------------------
# Fixers (surgical; do not clobber author comments / formatting)
# ---------------------------------------------------------------------------
def fix_blackbox(text, missing, extras):
    lines = text.splitlines(keepends=True)
    for host in sorted(extras, key=len, reverse=True):
        start = None
        for i, ln in enumerate(lines):
            if ln.strip() == f"- job_name: blackbox-{host}":
                start = i
                break
        if start is None:
            continue
        end = start + 1
        while end < len(lines) and not lines[end].startswith('  - job_name:'):
            end += 1
        del lines[start:end]
        note('removed', f"blackbox-{host} from promscrape.yaml")
    if missing:
        for h in sorted(missing):
            lines.append(
                f"  - job_name: blackbox-{h}\n"
                f"    metrics_path: /probe\n"
                f"    params:\n"
                f"      module: [http_2xx]\n"
                f"    static_configs:\n"
                f"      - targets:\n"
                f"          - \"https://{h}.{DOMAIN}\"\n"
                f"    relabel_configs:\n"
                f"      - source_labels: [__address__]\n"
                f"        target_label: __param_target\n"
                f"      - source_labels: [__param_target]\n"
                f"        target_label: instance\n"
                f"      - target_label: __address__\n"
                f"        replacement: blackbox-exporter:9115\n"
                f"\n"
            )
            note('added', f"blackbox-{h} to promscrape.yaml")
    return ''.join(lines) if text and not text.endswith('\n') else ''.join(lines)


def fix_homepage(text, missing):
    out = text.rstrip() + '\n'
    if missing:
        out += '\n# --- auto-added by scripts/check-consistency.py --fix ---\n'
        out += '- Deployed (auto):\n'
        for h in sorted(missing):
            name = h.title().replace('-', ' ')
            out += f"    - {name}:\n"
            out += f"        href: https://{h}.{DOMAIN}\n"
            out += '        description: <auto-added, fill in>\n'
            w = HOMEPAGE_WIDGETS.get(h)
            if w:
                out += f"        widget:\n"
                out += f"          type: {w['type']}\n"
                out += f"          url: {w['url']}\n"
                if w.get('var'):
                    out += f"          {w['key']}: '{{{{HOMEPAGE_VAR_{w['var']}}}}}'\n"
            note('added', f"{h} to homepage services.yaml")
    return out


def main():
    ap = argparse.ArgumentParser(description='gitops consistency checker')
    ap.add_argument('--dry-run', action='store_true', help='report only')
    ap.add_argument('--fix', action='store_true', help='auto-repair blackbox + homepage lists')
    ap.add_argument('--json', action='store_true', help='machine output; only exit code')
    ap.add_argument('--repo-path', default=None)
    args = ap.parse_args()
    globals()['REPO'] = Path(args.repo_path).resolve() if args.repo_path else REPO

    truth = traefik_hosts()
    bb = blackbox_hosts()
    hp = homepage_entries()
    auth = auth_hosts()
    gatus = gatus_hosts()
    readme = readme_hosts()
    hp_hosts = set(hp)

    missing_bb = sorted(truth - bb)
    extra_bb = sorted(bb - truth)
    stale_auth = sorted({h for h in auth - truth - AUTH_NO_HTTP_ROUTE if h not in AUTH_OK_NO_ROUTE})
    # "auth shows ALL apps": a host that is a real user-facing app (present on homepage)
    # and NOT an internal router/standalone service should have an Authentik app.
    uncovered_auth = sorted({
        h for h in truth & hp_hosts
        if h not in auth and h not in AUTH_NO_HTTP_ROUTE and h not in HOMEPAGE_NO_AUTH
    })
    missing_hp = sorted(truth - hp_hosts - HOMEPAGE_LAN_IP - {'homepage'})
    extra_hp = sorted(hp_hosts - truth)

    errors, warnings = [], []
    for h in missing_bb:
        errors.append(f"blackbox missing for '{h}.{DOMAIN}': Grafana won't probe it")
    for h in extra_bb:
        warnings.append(f"blackbox job blackbox-{h} probes a host that is not a Traefik route (stale)")
    for h in stale_auth:
        errors.append(f"Authentik app '{h}' has no Traefik route (stale — review terraform)")
    if uncovered_auth:
        warnings.append("user-facing app missing from Authentik (auth won't list it): " + ', '.join(uncovered_auth))
    for h in missing_hp:
        errors.append(f"homepage has no entry for '{h}.{DOMAIN}'")
    for h in extra_hp:
        warnings.append(f"homepage lists '{h}.{DOMAIN}' but no Traefik route (stale)")
    for h in sorted(truth & hp_hosts):
        if hp[h]['name'] in WIDGET_CAPABLE and not hp[h]['widget']:
            warnings.append(f"homepage '{hp[h]['name']}' supports a built-in widget but has none")
    # report-only tertiary views — collapsed to single lines to avoid noise
    gatus_gap = sorted(truth - gatus)
    readme_gap = sorted(readme - truth)
    if gatus_gap:
        warnings.append(
            f"gatus has no probe for {len(gatus_gap)} routed hosts (report-only, not auto-fixed): "
            + ', '.join(gatus_gap[:12]) + ('…' if len(gatus_gap) > 12 else '')
        )
    if readme_gap:
        warnings.append(
            f"README mentions {len(readme_gap)} hosts with no Traefik route (report-only): "
            + ', '.join(readme_gap[:12]) + ('…' if len(readme_gap) > 12 else '')
        )

    if args.fix and not args.dry_run:
        bb_path = REPO / 'stacks' / 'monitoring' / 'victoria-metrics' / 'promscrape.yaml'
        if missing_bb or (bb - truth):
            bb_path.write_text(fix_blackbox(bb_path.read_text(), missing_bb, extra_bb))
        hp_path = REPO / 'stacks' / 'homepage' / 'config' / 'services.yaml'
        if missing_hp:
            hp_path.write_text(fix_homepage(hp_path.read_text(), missing_hp))
        remaining = [h for h in missing_bb + stale_auth + missing_hp if h not in missing_bb]
        # recompute after fix
        missing_bb2 = sorted(truth - (bb_path.read_text() and set(re.findall(r'job_name:\s*blackbox-([a-z0-9-]+)', bb_path.read_text()))))
        remaining = [h for h in set(missing_bb + stale_auth + missing_hp)
                     if h in missing_bb2] + stale_auth

    if args.json:
        print(json.dumps({
            'errors': errors, 'warnings': warnings, 'truth': sorted(truth),
            'blackbox': sorted(bb), 'homepage': sorted(hp_hosts), 'auth': sorted(auth),
        }, indent=2))
        blocked = errors if args.dry_run or {e for e in errors if e.startswith('Authentik') or e.startswith('blackbox')} else [e for e in errors if any(x in e for x in ('blackbox', 'homepage'))]
        sys.exit(1 if errors else 0)

    print('Consistency check — %d Traefik-routed hosts\n' % len(truth))
    for e in errors:  print(f"  ✖ {e}")
    for w in warnings: print(f"  ! {w}")
    if not errors and not warnings:
        print('  ✓ no drift detected')
    print('\nauto-fixable: blackbox (promscrape.yaml) + homepage (services.yaml); manual: terraform/auth')
    sys.exit(1 if errors else 0)


if __name__ == '__main__':
    main()
