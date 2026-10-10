#!/usr/bin/env bash
# Upsert Terrakube drift-enforce template, OnCall webhook global var, and
# staggered hourly schedules on all HomeLab workspaces.
#
# Usage:
#   GRAFANA_ONCALL_WEBHOOK_URL=https://... ./scripts/terrakube/apply-drift-enforce.sh
#   # or after terraform/grafana apply:
#   GRAFANA_ONCALL_WEBHOOK_URL=$(cd terraform/grafana && tofu output -raw terrakube_drift_oncall_webhook_url) \
#     ./scripts/terrakube/apply-drift-enforce.sh
#
# Auth: TF_TOKEN_terrakube_api_dominiksiejak_pl or ~/.terraform.d/credentials.tfrc.json
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE_FILE="$ROOT/scripts/terrakube/templates/drift-enforce.yaml"
API="${TERRAKUBE_API:-https://terrakube-api.dominiksiejak.pl}"
ORG_NAME="${TERRAKUBE_ORG:-HomeLab}"
TEMPLATE_NAME="drift-enforce"
SCHEDULE_DESC="drift-enforce"

# workspace|cron|enabled (≤1/hour, 5m stagger). bash 3.2-safe (no assoc arrays).
# enabled=0 until workspace secrets plan cleanly; set ENABLE_ALL=1 to force on.
CRON_ROWS="
adguard|0 * * * *|0
authentik|5 * * * *|1
backblaze|10 * * * *|0
cloudflare|15 * * * *|1
gcp|20 * * * *|0
gitea|25 * * * *|0
grafana|30 * * * *|0
netbox|35 * * * *|0
proxmox|40 * * * *|0
routeros|45 * * * *|1
unifi|50 * * * *|1
"

token() {
  if [ -n "${TF_TOKEN_terrakube_api_dominiksiejak_pl:-}" ]; then
    printf '%s' "$TF_TOKEN_terrakube_api_dominiksiejak_pl"
    return
  fi
  python3 -c "
import json
print(json.load(open('$HOME/.terraform.d/credentials.tfrc.json'))['credentials']['terrakube-api.dominiksiejak.pl']['token'])
"
}

TOKEN="$(token)"
AUTH=( -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/vnd.api+json" )

api() {
  local method="$1" path="$2"
  shift 2
  curl -fsS -X "$method" "${AUTH[@]}" "${API}${path}" "$@"
}

api_code() {
  local method="$1" path="$2"
  shift 2
  curl -sS -o /tmp/tk-drift-resp.json -w "%{http_code}" -X "$method" "${AUTH[@]}" "${API}${path}" "$@"
}

echo "==> Resolve org ${ORG_NAME}"
ORG_JSON="$(api GET "/api/v1/organization")"
ORG_ID="$(python3 -c "
import json,sys
d=json.load(sys.stdin)
for o in d['data']:
  if o['attributes']['name']=='${ORG_NAME}':
    print(o['id']); break
else:
  sys.exit('org not found')
" <<<"$ORG_JSON")"
echo "    org id=${ORG_ID}"

echo "==> Upsert template ${TEMPLATE_NAME}"
# Strip comment-only header lines for tcl payload; keep flow: document.
TCL_B64="$(python3 -c "
import base64, pathlib, sys
text=pathlib.Path(sys.argv[1]).read_text()
# Drop leading #-comment lines before 'flow:'
lines=text.splitlines()
out=[]
seen_flow=False
for line in lines:
  if not seen_flow:
    if line.startswith('flow:'):
      seen_flow=True
      out.append(line)
    continue
  out.append(line)
if not seen_flow:
  raise SystemExit('flow: not found in template')
raw='\n'.join(out)+'\n'
print(base64.b64encode(raw.encode()).decode())
" "$TEMPLATE_FILE")"

TEMPLATES="$(api GET "/api/v1/organization/${ORG_ID}?include=template")"
TEMPLATE_ID="$(python3 -c "
import json,sys
d=json.load(sys.stdin)
for i in d.get('included') or []:
  if i['type']=='template' and i['attributes']['name']=='${TEMPLATE_NAME}':
    print(i['id']); break
" <<<"$TEMPLATES")"

BODY_TEMPLATE="$(python3 -c "
import json,sys
print(json.dumps({
  'data': {
    'type': 'template',
    'attributes': {
      'name': '${TEMPLATE_NAME}',
      'description': 'Hourly plan+apply drift remediate + Grafana OnCall notify',
      'version': '1.0.0',
      'tcl': sys.argv[1],
    }
  }
}))
" "$TCL_B64")"

if [ -n "$TEMPLATE_ID" ]; then
  BODY_PATCH="$(python3 -c "
import json,sys
b=json.loads(sys.argv[1])
b['data']['id']=sys.argv[2]
print(json.dumps(b))
" "$BODY_TEMPLATE" "$TEMPLATE_ID")"
  code="$(api_code PATCH "/api/v1/organization/${ORG_ID}/template/${TEMPLATE_ID}" -d "$BODY_PATCH")"
  echo "    patched template ${TEMPLATE_ID} http=${code}"
else
  code="$(api_code POST "/api/v1/organization/${ORG_ID}/template" -d "$BODY_TEMPLATE")"
  TEMPLATE_ID="$(python3 -c "import json; print(json.load(open('/tmp/tk-drift-resp.json'))['data']['id'])")"
  echo "    created template ${TEMPLATE_ID} http=${code}"
fi

if [ -z "${GRAFANA_ONCALL_WEBHOOK_URL:-}" ]; then
  echo "ERROR: set GRAFANA_ONCALL_WEBHOOK_URL (tofu output -raw terrakube_drift_oncall_webhook_url)" >&2
  exit 1
fi

echo "==> Upsert global ENV GRAFANA_ONCALL_WEBHOOK_URL"
GVARS="$(api GET "/api/v1/organization/${ORG_ID}/globalvar")"
GVAR_ID="$(python3 -c "
import json,sys
d=json.load(sys.stdin)
for v in d.get('data') or []:
  if v['attributes'].get('key')=='GRAFANA_ONCALL_WEBHOOK_URL':
    print(v['id']); break
" <<<"$GVARS")"

GVAR_BODY="$(python3 -c "
import json,os
print(json.dumps({
  'data': {
    'type': 'globalvar',
    'attributes': {
      'key': 'GRAFANA_ONCALL_WEBHOOK_URL',
      'value': os.environ['GRAFANA_ONCALL_WEBHOOK_URL'],
      'sensitive': True,
      'hcl': False,
      'category': 'ENV',
      'description': 'Grafana OnCall formatted_webhook for drift-enforce',
    }
  }
}))
")"

if [ -n "$GVAR_ID" ]; then
  GVAR_PATCH="$(python3 -c "
import json,sys
b=json.loads(sys.argv[1]); b['data']['id']=sys.argv[2]; print(json.dumps(b))
" "$GVAR_BODY" "$GVAR_ID")"
  code="$(api_code PATCH "/api/v1/organization/${ORG_ID}/globalvar/${GVAR_ID}" -d "$GVAR_PATCH")"
  echo "    patched globalvar ${GVAR_ID} http=${code}"
else
  code="$(api_code POST "/api/v1/organization/${ORG_ID}/globalvar" -d "$GVAR_BODY")"
  echo "    created globalvar http=${code}"
fi

echo "==> Upsert staggered schedules"
WS_JSON="$(api GET "/api/v1/organization/${ORG_ID}?include=workspace")"
python3 - "$WS_JSON" <<'PY' > /tmp/tk-ws-map.json
import json,sys
d=json.loads(sys.argv[1])
out={}
for i in d.get("included") or []:
  if i["type"]=="workspace":
    out[i["attributes"]["name"]]=i["id"]
json.dump(out, sys.stdout)
PY

echo "$CRON_ROWS" | while IFS='|' read -r ws cron enabled_flag; do
  [ -z "${ws:-}" ] && continue
  if [ "${ENABLE_ALL:-0}" = "1" ]; then
    enabled_flag=1
  fi
  enabled_json=false
  [ "$enabled_flag" = "1" ] && enabled_json=true
  wid="$(python3 -c "import json; print(json.load(open('/tmp/tk-ws-map.json')).get('$ws',''))")"
  if [ -z "$wid" ]; then
    echo "    WARN: workspace ${ws} missing; skip"
    continue
  fi
  SCH="$(api GET "/api/v1/organization/${ORG_ID}/workspace/${wid}/schedule")"
  SID="$(python3 -c "
import json,sys
d=json.load(sys.stdin)
for s in d.get('data') or []:
  if s['attributes'].get('description')=='${SCHEDULE_DESC}':
    print(s['id']); break
" <<<"$SCH")"

  SCH_BODY="$(python3 -c "
import json,sys
print(json.dumps({
  'data': {
    'type': 'schedule',
    'attributes': {
      'cron': sys.argv[1],
      'description': '${SCHEDULE_DESC}',
      'enabled': sys.argv[3] == 'true',
      'templateReference': sys.argv[2],
    }
  }
}))
" "$cron" "$TEMPLATE_ID" "$enabled_json")"

  if [ -n "$SID" ]; then
    SCH_PATCH="$(python3 -c "
import json,sys
b=json.loads(sys.argv[1]); b['data']['id']=sys.argv[2]; print(json.dumps(b))
" "$SCH_BODY" "$SID")"
    code="$(api_code PATCH "/api/v1/organization/${ORG_ID}/workspace/${wid}/schedule/${SID}" -d "$SCH_PATCH")"
    echo "    ${ws}: patched schedule ${SID} cron='${cron}' enabled=${enabled_json} http=${code}"
  else
    code="$(api_code POST "/api/v1/organization/${ORG_ID}/workspace/${wid}/schedule" -d "$SCH_BODY")"
    echo "    ${ws}: created schedule cron='${cron}' enabled=${enabled_json} http=${code}"
  fi
done

echo "==> Done. Template ${TEMPLATE_NAME}=${TEMPLATE_ID}"
echo "    Schedules enabled. Ensure workspace vars are healthy before relying on hourly runs."
echo "    See scripts/terrakube/README.md"
