#!/usr/bin/env python3
"""Fail CI if high-severity gitops regressions land again."""

from pathlib import Path
import sys

REPO = Path(__file__).resolve().parent.parent
errors = []


def check(cond, msg):
    if not cond:
        errors.append(msg)


dyn = (REPO / 'stacks/traefik/dynamic.yaml').read_text()
check('b3BlbmNvZGU6c3VwZXItc2VjcmV0' not in dyn, 'opencode basic auth secret is hardcoded in dynamic.yaml')
check("Authorization: \"Basic " not in dyn, 'Traefik must not inject a static Authorization header')
check('basicAuth:' in dyn and 'OPENCODE_HTPASSWD' in dyn, 'opencode route must use Traefik basicAuth from env')
check('webhook-rate-limit' in dyn, 'n8n webhook router must be rate-limited')

n8n = (REPO / 'stacks/n8n/compose.yaml').read_text()
check('N8N_SSRF_PROTECTION_ENABLED: true' in n8n, 'n8n SSRF protection must be enabled')
check('N8N_BLOCK_ENV_ACCESS_IN_NODE: "true"' in n8n, 'n8n Code nodes must not read $env')
check('authentik@docker' in n8n, 'n8n UI must use Authentik forward-auth')

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


if errors:
    print('security invariants failed:')
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)

print('security invariants ok')
