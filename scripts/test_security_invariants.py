#!/usr/bin/env python3
"""Fail CI if high-severity gitops regressions land again."""

from pathlib import Path
import re
import sys

REPO = Path(__file__).resolve().parent.parent
errors = []


def check(cond, msg):
    if not cond:
        errors.append(msg)


dyn = (REPO / 'stacks/traefik/dynamic.yaml').read_text()
check('b3BlbmNvZGU6c3VwZXItc2VjcmV0' not in dyn, 'opencode basic auth secret is hardcoded in dynamic.yaml')
check('Basic b3BlbmNvZGU6' not in dyn, 'Traefik must not inject a static Authorization header')
# Edge auth for opencode is Authentik SSO; Traefik only injects the upstream
# credential from env so the browser never sees a prompt.
opencode_router = re.search(r'\n    opencode:\n(?:.*\n)*?      service: opencode', dyn)
opencode_router = opencode_router.group(0) if opencode_router else ''
check('authentik@docker' in opencode_router, 'opencode route must use Authentik forward-auth')
check('opencode-upstream-auth@file' in opencode_router, 'opencode route must inject the upstream basic credential')
check('opencode-basic-auth' not in dyn, 'opencode must not prompt for Traefik basicAuth')
check('webhook-rate-limit' in dyn, 'n8n webhook router must be rate-limited')
ex = (REPO / 'stacks/traefik/traefik.env.example').read_text()
check('OPENCODE_UPSTREAM_BASIC=' in ex, 'traefik.env.example must document OPENCODE_UPSTREAM_BASIC')
check('OPENCODE_HTPASSWD' not in ex, 'retired OPENCODE_HTPASSWD must not be documented anymore')

n8n = (REPO / 'stacks/n8n/compose.yaml').read_text()
check('N8N_SSRF_PROTECTION_ENABLED: true' in n8n, 'n8n SSRF protection must be enabled')
_ssrf = re.search(r'N8N_SSRF_ALLOWED_IP_RANGES:\s*"([^"]*)"', n8n)
check(bool(_ssrf) and '192.168.89.1/32' in _ssrf.group(1).split(','),
      'n8n must allowlist the RouterOS LAN IP for SSRF')
check('N8N_BLOCK_ENV_ACCESS_IN_NODE: "true"' in n8n, 'n8n Code nodes must not read $env')
check('authentik@docker' not in n8n, 'n8n UI must not use a second Authentik proxy app')
ex_n8n = (REPO / 'stacks/n8n/n8n.env.example').read_text()
check('ROUTEROS_API_URL=http://192.168.89.1/rest' in ex_n8n, 'n8n must call RouterOS on the LAN, not via Authentik')
check('router.dominiksiejak.pl/rest' not in ex_n8n, 'n8n must not hairpin RouterOS REST through Traefik/Authentik')

pg = (REPO / 'stacks/postgres/compose.yaml').read_text()
check('127.0.0.1:5432:5432' in pg, 'Postgres must bind localhost only')
check('0.0.0.0:5432' not in pg, 'Postgres must not listen on all interfaces')

tr = (REPO / 'stacks/traefik/traefik.yaml').read_text()
check('insecure: false' in tr, 'Traefik API must not be insecure')

notif = (REPO / 'terraform/authentik/notifications.tf').read_text()
check('webhook_mapping_body' in notif, 'Authentik webhook must map event action/client_ip in the body')
check("action = \"login\"" in notif, 'Authentik event matcher must include login')

wf = (REPO / 'stacks/n8n/workflows/authentik-login-firewall.json').read_text()
check('Validate IP' in wf, 'firewall webhook must validate IPv4')
check('full_body' not in wf, 'webhook responses must not echo the Authentik payload')
check('Debug Payload' not in wf, 'debug node must not sit on the webhook hot path')
check('const pass = $env.ROUTEROS_API_PASS' not in wf, 'Code nodes must not read RouterOS password from $env')

mqtt = (REPO / 'stacks/hass/mosquitto.conf').read_text()
check('listener_allow_anonymous false' in mqtt, 'LAN MQTT listener must require a password')
check('listener 1883 127.0.0.1' in mqtt, 'localhost MQTT listener must remain for HA/healthcheck')
check('listener 1883 0.0.0.0' not in mqtt, 'MQTT must not bind 0.0.0.0 on the same port as localhost')

cloud = (REPO / 'terraform/cloudflare/main.tf').read_text()
check('from = cloudflare_zero_trust_tunnel_cloudflared.homelab' in cloud, 'Cloudflare tunnel rename needs a moved block')
check('name              = "dominiksiejak"' in cloud, 'Pages project name must match dominiksiejak.pages.dev')

portainer_prov = (REPO / 'terraform/portainer/providers.tf').read_text()
check('skip_ssl_verify = var.portainer_skip_ssl_verify' in portainer_prov,
      'Portainer provider must gate skip_ssl_verify behind a variable (default false)')
check('skip_ssl_verify = true' not in portainer_prov,
      'Portainer must not hardcode skip_ssl_verify = true')

cf_vars = (REPO / 'terraform/cloudflare/variables.tf').read_text()
check('tcp://v-maintenance-firebird:3050' not in cf_vars,
      'Firebird TCP must not be in default tunnel_apps')

ak = (REPO / 'stacks/authentik/compose.yaml').read_text()
check('trustForwardHeader: false' in ak,
      'Authentik forwardauth must not trust client X-Forwarded-* (trustForwardHeader: false)')
check('AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS' in ak,
      'Authentik must pin TRUSTED_PROXY_CIDRS to private/Docker ranges')

# Phase: compose .env files are rendered from Phase; Vault static roles must not
# rotate the Phase DB password out from under phase.env (same Infisical footgun).
phase_compose = REPO / 'stacks/phase/compose.yaml'
check(phase_compose.is_file(), 'stacks/phase/compose.yaml must exist')
if phase_compose.is_file():
    phase = phase_compose.read_text()
    check('authentik@docker' not in phase, 'Phase UI must use native Authentik OAuth, not Traefik forward-auth')
    check('Host(`phase.dominiksiejak.pl`)' in phase, 'Phase must be routed at phase.dominiksiejak.pl')
    check('PathPrefix(`/service`)' in phase, 'Phase backend must be exposed under /service')
    check('container_name: phase-redis' in phase, 'Phase Redis must not steal the redis alias on database')
    check('database:' in phase, 'Phase backend must join the database network')

vault_locals = (REPO / 'terraform/vault/locals.tf').read_text()
check('phase_user' not in vault_locals, 'Phase DB password must not be a Vault static role')
pg_locals = (REPO / 'terraform/postgres/locals.tf').read_text()
check('phase_user' in pg_locals, 'Phase DB user must be provisioned in terraform/postgres')

portainer_mk = (REPO / 'terraform/portainer/Makefile').read_text()
check('render-secrets' in portainer_mk, 'Portainer sync must render Phase secrets')
check(re.search(r'sync-portainer:[^\n]*render-secrets', portainer_mk) is not None,
      'sync-portainer must run render-secrets before rsync')

ak_locals = (REPO / 'terraform/authentik/locals.tf').read_text()
check('api/auth/callback/authentik' in ak_locals, 'Authentik must register the Phase OAuth callback')

auth_class = (REPO / 'scripts/auth_classification.yaml').read_text()
check(re.search(r'^native-oidc:\n(?:  - .+\n)*  - phase\b', auth_class, re.M) is not None,
      'phase.dominiksiejak.pl must be classified native-oidc')

map_path = REPO / 'scripts/phase_env_map.yaml'
check(map_path.is_file(), 'scripts/phase_env_map.yaml must map compose env files to Phase apps')
if map_path.is_file():
    import yaml
    mapping = yaml.safe_load(map_path.read_text()) or {}
    mapped = {item['path'] for item in mapping.get('apps', [])}
    bootstrap = set(mapping.get('bootstrap', []))
    examples = {
        str(p.relative_to(REPO / 'stacks'))[:-len('.example')]
        for p in (REPO / 'stacks').rglob('*.env.example')
    }
    missing = sorted((examples - bootstrap) - mapped)
    extra = sorted(mapped - examples)
    check(not missing, f'phase_env_map.yaml missing apps for {missing}')
    check(not extra, f'phase_env_map.yaml has unknown paths {extra}')
    check('phase/phase.env' in bootstrap, 'phase.env is bootstrap and must not be fetched from Phase')


if errors:
    print('security invariants failed:')
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)

print('security invariants ok')
