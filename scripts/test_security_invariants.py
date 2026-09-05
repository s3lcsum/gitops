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
check('authentik@docker' in dyn and 'opencode-upstream-auth@file' in dyn,
      'opencode route must use Authentik edge + upstream Basic from env')
check('OPENCODE_UPSTREAM_BASIC' in dyn, 'opencode upstream Authorization must come from env')
check('opencode-basic-auth' not in dyn and 'OPENCODE_HTPASSWD' not in dyn,
      'legacy opencode Traefik basicAuth middleware must be gone')
check('webhook-rate-limit' in dyn, 'n8n webhook router must be rate-limited')
ex = (REPO / 'stacks/traefik/traefik.env.example').read_text()
check('OPENCODE_UPSTREAM_BASIC=' in ex, 'traefik.env.example must document OPENCODE_UPSTREAM_BASIC')

n8n = (REPO / 'stacks/n8n/compose.yaml').read_text()
check('N8N_SSRF_PROTECTION_ENABLED: true' in n8n, 'n8n SSRF protection must be enabled')
check('N8N_SSRF_ALLOWED_IP_RANGES: "192.168.89.1/32"' in n8n, 'n8n must allowlist the RouterOS LAN IP for SSRF')
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

gitignore = (REPO / '.gitignore').read_text()
check('**/.wrangler/' in gitignore, 'root .gitignore must ignore Wrangler caches')

check(not (REPO / 'terraform/05-network').exists(),
      'numbered Terragrunt forks must not sit next to live GCS modules')
check(not (REPO / 'terraform/30-services').exists(),
      'portainer rsync --delete wrapper must not exist')

check(not (REPO / 'terraform/cloudflare/cribfinder-catalog.json').exists(),
      'cribfinder catalog dump must not be in this public repo')
links = (REPO / 'terraform/cloudflare/shorturl-links.json').read_text()
check('wa.me' not in links, 'shorturl catalog must not include a WhatsApp / phone URL')
shorturl_js = (REPO / 'terraform/cloudflare/shorturl.js').read_text()
check('JSON.stringify(links' not in shorturl_js, 'shorturl GET / must not dump the catalog')
check('ALLOWED_PROTOCOLS' in shorturl_js, 'shorturl must allowlist redirect schemes')
check('url.dominiksiejak.pl' in cloud and 'cribfinder.dominiksiejak.pl' in cloud,
      'country WAF skip list must include url. and cribfinder.')

tf_make = (REPO / 'terraform/Makefile').read_text()
check('APPLY_MODULES' in tf_make and 'grep -vx terraform-cloud' in tf_make,
      'apply-all must skip terraform-cloud and non-module directories')

portainer_mk = (REPO / 'terraform/portainer/Makefile').read_text()
check("--exclude 'adguard/conf/AdGuardHome.yaml'" in portainer_mk,
      'portainer rsync --delete must exclude host-managed secrets')
check("--exclude '*.env'" in portainer_mk,
      'portainer rsync --delete must exclude *.env so host secrets survive sync')


if errors:
    print('security invariants failed:')
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)

print('security invariants ok')
