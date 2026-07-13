#!/usr/bin/env python3
"""
Daily stack update checker for gitops repo.
Scans stacks/*/compose.yaml for pinned images, checks registries for newer versions,
updates safe minor/patch bumps, and outputs a JSON summary for the orchestrator.

Usage:
  python3 scripts/check-stack-updates.py [--dry-run] [--repo-path PATH]

Output (JSON to stdout):
  {
    "updated": [
      {"stack": "adguard", "service": "adguard", "image": "ghcr.io/adguard/adguardhome",
       "from": "v0.107.77", "to": "v0.107.80", "bump": "patch"}
    ],
    "needs_review": [
      {"stack": "traefik", "service": "traefik", "image": "ghcr.io/traefik/traefik",
       "from": "v3.7.5", "to": "v4.0.0", "bump": "major", "reason": "Major version bump",
       "release_url": "https://github.com/traefik/traefik/releases/tag/v4.0.0"}
    ],
    "unchanged": [...],
    "errors": [...]
  }
"""

import json
import os
import re
import subprocess
import sys
import argparse
from pathlib import Path

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
parser = argparse.ArgumentParser()
parser.add_argument('--dry-run', action='store_true', help="Don't modify files")
parser.add_argument('--repo-path', default=None, help='Path to gitops repo')
args = parser.parse_args()

REPO = Path(args.repo_path).resolve() if args.repo_path else Path(__file__).resolve().parent.parent
STACKS_DIR = REPO / 'stacks'
DRY_RUN = args.dry_run

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def sh(cmd, timeout=30):
    """Run a shell command, return (stdout, stderr, rc)."""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip(), r.stderr.strip(), r.returncode
    except subprocess.TimeoutExpired:
        return '', f"timeout ({timeout}s)", -1
    except FileNotFoundError as e:
        return '', f"command not found: {e}", -1


def parse_image_tag(image_str):
    """
    Parse an 'image:' value from compose file.
    Returns (registry, image_path, tag) or None.
    Examples:
      'ghcr.io/adguard/adguardhome:v0.107.77'  -> ('ghcr.io', 'adguard/adguardhome', 'v0.107.77')
      'postgres:18.4'                           -> ('docker.io', 'library/postgres', '18.4')
      'lscr.io/linuxserver/prowlarr:2.4.0'      -> ('lscr.io', 'linuxserver/prowlarr', '2.4.0')
    """
    image_str = image_str.strip().strip('"').strip("'")
    if not image_str:
        return None

    # Split on last colon for tag (but ignore port numbers like host:port/image)
    # If image has a port number (e.g., localhost:5000/myimage:tag), the first colon
    # before a slash is part of the registry. Detect registry-based colon.
    tag = None
    # Try splitting on last colon
    if ':' in image_str:
        # Check if it's a registry:port pattern
        parts = image_str.split(':')
        if len(parts) > 2:
            # e.g., host:port/image:tag - the second-to-last colon is the tag
            tag = parts[-1]
            image_path_part = ':'.join(parts[:-1])
        else:
            tag = parts[1]
            image_path_part = parts[0]
    else:
        image_path_part = image_str

    # Parse registry and path
    if '/' in image_path_part:
        first = image_path_part.split('/')[0]
        # Check if first segment is a registry hostname (has a dot or colon)
        if '.' in first or ':' in first or first == 'localhost':
            registry = first
            image_path = '/'.join(image_path_part.split('/')[1:])
        else:
            registry = 'docker.io'
            image_path = image_path_part
    else:
        registry = 'docker.io'
        image_path = f"library/{image_path_part}"

    return registry, image_path, tag or 'latest'


# Tags to exclude (non-stable variants)
EXCLUDED_TAG_PATTERNS = re.compile(
    r'(nightly|unstable|dev|alpha|beta|rc\d*$|pre|master|edge|next|test|'
    r'canary|snapshot|experimental|'
    r'\bb\.\d+)', re.IGNORECASE
)


def is_stable_tag(tag):
    """Return True if tag is a stable release (not nightly/dev/beta/rc/etc)."""
    return not EXCLUDED_TAG_PATTERNS.search(tag)


def prefer_stable_version(bucket_tags):
    """Given tags with the same base semver, prefer the simplest stable one.
    E.g. ['2.4.0', '2.4.0.5397-ls153'] -> '2.4.0'"""
    stable = [t for t in bucket_tags if is_stable_tag(t)]
    candidates = stable if stable else bucket_tags
    # Sort by: shorter tag first, then alphabetical
    candidates.sort(key=lambda t: (len(t), t))
    return candidates[0]


def semver_tuple(tag):
    """
    Extract (major, minor, patch) from a version tag.
    Strips leading 'v' or 'V'. Returns None if not semver-like.
    Handles date-based (2026.7.1), semver (1.2.3), and suffixes (-alpine, -sc, etc.)
    """
    t = tag.lstrip('vV')
    # Strip everything from the first letter suffix (e.g. -alpine, _sc, -slim)
    # But NOT numbers as part of the version (e.g., 2.4.0.5397 should become 2.4.0)
    m = re.match(r'^(\d+(?:\.\d+){1,3})', t)
    if m:
        version_core = m.group(1)
        # Take only first 3 parts if there are 4
        parts = version_core.split('.')
        core_3 = '.'.join(parts[:3])
        m2 = re.match(r'^(\d+)\.(\d+)\.(\d+)$', core_3)
        if m2:
            return (int(m2.group(1)), int(m2.group(2)), int(m2.group(3)))
        # Two-part version like 18.4
        m2 = re.match(r'^(\d+)\.(\d+)$', core_3)
        if m2:
            return (int(m2.group(1)), int(m2.group(2)), 0)
    return None


def version_sort_key(tag):
    """Sort key for version tags. Non-semver tags sort last."""
    sv = semver_tuple(tag)
    if sv:
        return (0, sv[0], sv[1], sv[2])
    return (1, tag)


def bump_type(current_tag, new_tag):
    """Returns 'major', 'minor', 'patch', or None."""
    c = semver_tuple(current_tag)
    n = semver_tuple(new_tag)
    if c and n:
        if c == n:
            return None  # Same version number (different suffix like -alpine), not an update
        if n[0] > c[0]:
            return 'major'
        if n[0] == c[0] and n[1] > c[1]:
            return 'minor'
        if n[0] == c[0] and n[1] == c[1] and n[2] > c[2]:
            return 'patch'
        # Same base version but different tag (e.g., 18.4 -> 18.4-alpine) - not an update
        return None
    return None


def parse_compose_images(compose_path):
    """
    Parse a compose.yaml and return list of (service_name, image_str) tuples.
    Handles YAML anchors/aliases by tracking `x-*` blocks.
    """
    images = []
    current_service = None
    in_service_block = False
    anchor_images = {}  # anchor_name -> image_str

    with open(compose_path) as f:
        lines = f.readlines()

    for i, line in enumerate(lines):
        stripped = line.rstrip()

        # Detect anchor definitions in x- blocks:  x-foo: &bar   image: xxx
        anchor_match = re.match(r'^\s*x-(\w+):\s*&(\w+)', stripped)
        if anchor_match:
            anchor_name = anchor_match.group(2)
            # Look ahead for image: under this anchor
            for j in range(i + 1, min(i + 10, len(lines))):
                img_match = re.match(r'^\s+image:\s*(.+)', lines[j])
                if img_match:
                    anchor_images[anchor_name] = img_match.group(1).strip()
                    break
                if re.match(r'^\s*\w', lines[j]) or re.match(r'^\s*$', lines[j]):
                    break

        # Detect service definitions:  service_name:
        svc_match = re.match(r'^\s{2}(\w[\w-]*):\s*$', stripped)
        if svc_match:
            current_service = svc_match.group(1)
            in_service_block = current_service is not None
            continue

        # Image line
        img_match = re.match(r'^\s+image:\s*(.+)', stripped)
        if img_match and current_service:
            img_val = img_match.group(1).strip()
            # If it's an alias reference: *anchor
            if img_val.startswith('*'):
                anchor = img_val[1:]
                resolved = anchor_images.get(anchor)
                if resolved:
                    images.append((current_service, resolved))
            else:
                images.append((current_service, img_val))
            continue

        # Detect end of a service block (next top-level key)
        if re.match(r'^\w', stripped) and current_service and not stripped.startswith(' '):
            current_service = None

    return images


# ---------------------------------------------------------------------------
# Registry checkers
# ---------------------------------------------------------------------------
def check_ghcr(registry, image_path, current_tag):
    """Check GHCR image for newer tags using GitHub Releases API.
    image_path = 'org/repo'. Maps to github.com/org/repo.
    Uses `gh api` for authenticated access.
    Returns (latest_tag, bump_type_or_none, error_or_none).
    """
    # linuxserver images on GHCR have messy release tags; use Docker Hub instead
    if image_path.startswith('linuxserver/'):
        return check_docker_hub('docker.io', image_path, current_tag)

    # Some GHCR images don't map 1:1 to GitHub repo names
    ghcr_repo_mappings = {
        'adguard/adguardhome': 'AdguardTeam/AdGuardHome',
        'gitea/gitea': 'go-gitea/gitea',
        'eclipse-mosquitto/eclipse-mosquitto': 'eclipse-mosquitto/mosquitto',
        'victoriametrics/victoria-metrics': 'VictoriaMetrics/VictoriaMetrics',
        'valkey/valkey': 'valkey-io/valkey',
        'adminer/adminer': 'vrana/adminer',
        'prometheuscommunity/postgres-exporter': 'prometheus-community/postgres_exporter',
        'hashicorp/vault': 'hashicorp/vault',
    }

    repo_path = ghcr_repo_mappings.get(image_path, image_path)

    # Special handling for n8n which uses 'n8n@x.y.z' tag format
    is_n8n = image_path == 'n8n-io/n8n'

    jq_filter = '.[] | select(.prerelease == false) | .tag_name'
    api_url = f"repos/{repo_path}/releases?per_page=20"
    out, err, rc = sh(['gh', 'api', api_url, '--jq', jq_filter], timeout=20)
    if rc != 0:
        return None, None, f"GHCR/API: {err or out[:200]}"

    tags = [t.strip() for t in out.split('\n') if t.strip()]
    if not tags:
        # Fallback: check git tags (some repos don't use GitHub Releases)
        api_url = f"repos/{repo_path}/tags?per_page=20"
        out2, err2, rc2 = sh(['gh', 'api', api_url, '--jq', '.[].name'], timeout=20)
        if rc2 == 0:
            tags = [t.strip() for t in out2.split('\n') if t.strip()]

    # n8n tags are "n8n@x.y.z" - strip the prefix
    if is_n8n:
        cleaned = []
        for t in tags:
            m = re.match(r'^n8n@(\d+(\.\d+)+)$', t)
            if m:
                cleaned.append(m.group(1))
        tags = cleaned
    else:
        # Filter version-like tags only, exclude non-stable
        tags = [t for t in tags if is_stable_tag(t) and re.match(r'^v?\d+(\.\d+)+(?:[-_][a-zA-Z0-9.]+)?$', t)]

    if not tags:
        return None, None, f"GHCR/API: no version tags in releases for {repo_path}"

    # Deduplicate: group by base semver, prefer simplest stable tag per group
    by_semver = {}
    for t in tags:
        sv = semver_tuple(t)
        if sv:
            by_semver.setdefault(sv, []).append(t)
    if by_semver:
        tags = [prefer_stable_version(group) for group in by_semver.values()]

    tags.sort(key=version_sort_key, reverse=True)
    latest = tags[0]

    if latest == current_tag:
        return None, None, None  # Already latest

    bt = bump_type(current_tag, latest)
    return latest, bt, None


def check_docker_hub(registry, image_path, current_tag):
    """Check Docker Hub for newer tags.
    Returns (latest_tag, bump_type_or_none, error_or_none).
    """
    hub_url = f"https://hub.docker.com/v2/repositories/{image_path}/tags?page_size=100&page=1&ordering=last_updated"
    out, err, rc = sh(['curl', '-s', '-f', '--max-time', '15', hub_url])
    if rc != 0:
        return None, None, f"Docker Hub API error: {err or out[:200]}"

    try:
        data = json.loads(out)
        tags = [r['name'] for r in data.get('results', [])]
    except (json.JSONDecodeError, KeyError):
        return None, None, 'Docker Hub: invalid JSON response'

    if not tags:
        return None, None, f"Docker Hub: no tags found for {image_path}"

    # Filter only stable version tags (semver, date-based), strip v prefix
    version_tags = []
    for t in tags:
        if not is_stable_tag(t):
            continue
        t_stripped = t.lstrip('vV')
        if re.match(r'^\d+(\.\d+)+(?:[-_][a-zA-Z0-9.]+)?$', t_stripped):
            version_tags.append(t)

    if not version_tags:
        return None, None, f"Docker Hub: no version tags found for {image_path}"

    # Deduplicate by base semver, prefer simplest tag per version
    by_semver = {}
    for t in version_tags:
        sv = semver_tuple(t)
        if sv:
            by_semver.setdefault(sv, []).append(t)
    if by_semver:
        version_tags = [prefer_stable_version(group) for group in by_semver.values()]

    version_tags.sort(key=version_sort_key, reverse=True)
    latest = version_tags[0]

    if latest == current_tag:
        return None, None, None

    bt = bump_type(current_tag, latest)
    return latest, bt, None


def check_lscr(registry, image_path, current_tag):
    """Check LinuxServer.io images via Docker Hub API (same images)."""
    # lscr.io/linuxserver/xxx -> linuxserver/xxx on Docker Hub
    return check_docker_hub('docker.io', image_path, current_tag)


def check_registry(registry, image_path, current_tag):
    """Dispatch to the right registry checker.
    Returns (latest_tag, bump_type_str_or_none, error_str_or_none).
    Exactly one of latest_tag or error_str is non-None.
    """
    if registry == 'ghcr.io':
        return check_ghcr(registry, image_path, current_tag)
    elif registry == 'docker.io':
        return check_docker_hub(registry, image_path, current_tag)
    elif registry == 'lscr.io':
        return check_lscr(registry, image_path, current_tag)
    else:
        return None, None, f"Unknown registry: {registry}"


# ---------------------------------------------------------------------------
# Breaking change detection
# ---------------------------------------------------------------------------
def get_release_notes_url(registry, image_path, tag):
    """Try to find the release notes URL for a given image + tag."""
    if registry == 'ghcr.io':
        # Map GHCR image path to GitHub repo
        # Heuristics: ghcr.io/owner/repo -> github.com/owner/repo
        # But some don't match: ghcr.io/adguard/adguardhome -> AdguardTeam/AdGuardHome
        # Use common mappings
        known_mappings = {
            'adguard/adguardhome': 'AdguardTeam/AdGuardHome',
            'grafana/synthetic-monitoring-agent': 'grafana/synthetic-monitoring-agent',
            'goauthentik/server': 'goauthentik/authentik',
            'netboxcommunity/netbox': 'netbox-community/netbox',
            'valkey/valkey': 'valkey-io/valkey',
            'home-assistant/home-assistant': 'home-assistant/core',
            'koenkk/zigbee2mqtt': 'Koenkk/zigbee2mqtt',
            'eclipse-mosquitto/eclipse-mosquitto': 'eclipse-mosquitto/mosquitto',
            'linuxserver/calibre': 'linuxserver/docker-calibre',
            'linuxserver/calibre-web': 'linuxserver/docker-calibre-web',
            'linuxserver/qbittorrent': 'linuxserver/docker-qbittorrent',
            'linuxserver/sabnzbd': 'linuxserver/docker-sabnzbd',
            'linuxserver/sonarr': 'linuxserver/docker-sonarr',
            'linuxserver/jellyfin': 'linuxserver/docker-jellyfin',
            'qdm12/gluetun': 'qdm12/gluetun',
            'amir20/dozzle': 'amir20/dozzle',
            'traefik/traefik': 'traefik/traefik',
            'gethomepage/homepage': 'gethomepage/homepage',
            'gitea/gitea': 'go-gitea/gitea',
            'cloudflare/cloudflared': 'cloudflare/cloudflared',
            'simoncaron/traefik-adguard-auto-rewrites': 'simoncaron/traefik-adguard-auto-rewrites',
            'n8n-io/n8n': 'n8n-io/n8n',
            'dani-garcia/vaultwarden': 'dani-garcia/vaultwarden',
            'grafana/grafana': 'grafana/grafana',
            'victoriametrics/victoria-metrics': 'VictoriaMetrics/VictoriaMetrics',
            'aceberg/watchyourlan': 'aceberg/watchyourlan',
            'dictionarry-hub/profilarr': 'dictionarry-hub/profilarr',
            'seerr-team/seerr': 'seerr-team/seerr',
            'saihgupr/homeassistanttimemachine': 'saihgupr/homeassistanttimemachine',
            'flaresolverr/flaresolverr': 'FlareSolverr/FlareSolverr',
            'prometheuscommunity/postgres-exporter': 'prometheus-community/postgres_exporter',
            'adminer/adminer': 'vrana/adminer',
            'twin/gatus': 'TwiN/gatus',
        }
        repo = known_mappings.get(image_path)
        if not repo:
            # Fallback: guess from image_path
            parts = image_path.split('/')
            if len(parts) >= 2:
                repo = f"{parts[0]}/{parts[1]}"
            else:
                return None
        return f"https://github.com/{repo}/releases/tag/{tag}"

    elif registry == 'docker.io':
        # Docker Hub - try to map to GitHub
        known_hub_mappings = {
            'library/postgres': ('postgres/postgres', 'https://github.com/postgres/postgres/releases/tag/REL_{tag}'),
            'library/mongo': ('mongo/mongo', 'https://github.com/mongodb/mongo/releases/tag/r{tag}'),
        }
        if image_path in known_hub_mappings:
            _, url = known_hub_mappings[image_path]
            return url.replace('{tag}', tag.lstrip('vV'))
        return None

    elif registry == 'lscr.io':
        # LinuxServer images -> github.com/linuxserver/docker-<image>
        img_name = image_path.split('/')[-1]
        return f"https://github.com/linuxserver/docker-{img_name}/releases"
    return None


def check_for_breaking_changes(registry, image_path, from_tag, to_tag, bump):
    """
    Determine if the update likely has breaking changes.
    Returns None if safe, or a reason string if needs review.
    """
    # Major bump is always needs review
    if bump == 'major':
        url = get_release_notes_url(registry, image_path, to_tag)
        reason = f"Major version bump ({from_tag} -> {to_tag})"
        if url:
            reason += f" | Release notes: {url}"
        return reason

    # Minor bump - usually safe for most infra services, but flag some
    # critical services (traefik, authentik, database core, vault)
    critical_services = [
        'traefik/traefik',
        'goauthentik/server',
        'library/postgres',
        'hashicorp/vault',
        'valkey/valkey',
        'library/mongo',
    ]
    for crit in critical_services:
        if crit in image_path:
            url = get_release_notes_url(registry, image_path, to_tag)
            reason = f"Critical service minor update ({from_tag} -> {to_tag})"
            if url:
                reason += f" | Release notes: {url}"
            return reason

    # Patch bump - safe
    return None


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    results = {
        'updated': [],
        'needs_review': [],
        'unchanged': [],
        'errors': [],
        'dry_run': DRY_RUN,
    }

    if not STACKS_DIR.is_dir():
        results['errors'].append(f"Stacks directory not found: {STACKS_DIR}")
        print(json.dumps(results, indent=2))
        return

    stack_dirs = sorted([d for d in STACKS_DIR.iterdir() if d.is_dir()])
    if not stack_dirs:
        results['errors'].append('No stack directories found')
        print(json.dumps(results, indent=2))
        return

    for stack_dir in stack_dirs:
        compose_path = stack_dir / 'compose.yaml'
        if not compose_path.is_file():
            continue

        stack_name = stack_dir.name
        images = parse_compose_images(compose_path)
        if not images:
            continue

        for service_name, image_str in images:
            parsed = parse_image_tag(image_str)
            if parsed is None:
                continue

            registry, image_path, current_tag = parsed

            # Skip :latest - already tracking latest
            if current_tag == 'latest':
                results['unchanged'].append({
                    'stack': stack_name,
                    'service': service_name,
                    'image': image_str,
                    'reason': ':latest tag, skipping',
                })
                continue

            # Check registry
            new_tag, bt, error = check_registry(registry, image_path, current_tag)
            if error:
                results['errors'].append({
                    'stack': stack_name,
                    'service': service_name,
                    'image': image_str,
                    'error': error,
                })
                continue

            if new_tag is None:
                results['unchanged'].append({
                    'stack': stack_name,
                    'service': service_name,
                    'image': image_str,
                    'reason': f"Already at latest: {current_tag}",
                })
                continue

            # Determine bump type and check for breaking changes
            bt = bump_type(current_tag, new_tag) or 'unknown'

            # If "unknown" bump and same base version, skip (variant tag change, not an upgrade)
            if bt == 'unknown':
                c_sv = semver_tuple(current_tag)
                n_sv = semver_tuple(new_tag)
                if c_sv and n_sv and c_sv == n_sv:
                    results['unchanged'].append({
                        'stack': stack_name,
                        'service': service_name,
                        'image': image_str,
                        'reason': f"Same version, different variant ({current_tag} -> {new_tag}), skipping",
                    })
                    continue

            breaking_reason = check_for_breaking_changes(registry, image_path, current_tag, new_tag, bt)

            # Update the compose file if safe
            entry = {
                'stack': stack_name,
                'service': service_name,
                'image': f"{registry}/{image_path}",
                'from': current_tag,
                'to': new_tag,
                'bump': bt,
            }

            if breaking_reason and bt in ('major', 'minor'):
                entry['reason'] = breaking_reason
                release_url = get_release_notes_url(registry, image_path, new_tag)
                if release_url:
                    entry['release_url'] = release_url
                results['needs_review'].append(entry)
                continue

            # Safe to update
            old_line = f"image: {image_str}"
            new_image_str = image_str.replace(f":{current_tag}", f":{new_tag}", 1)
            new_line = f"image: {new_image_str}"

            if not DRY_RUN:
                compose_text = compose_path.read_text()
                # Be precise about the replacement
                compose_text = compose_text.replace(old_line, new_line)
                compose_path.write_text(compose_text)
                entry['compose_file'] = str(compose_path)

            results['updated'].append(entry)

    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
