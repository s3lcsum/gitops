#!/usr/bin/env bash
# Sync Servers/terrakube-tofu fields → Terrakube workspace vars.
# Skips values starting with REPLACE_ME.
#
# Auth: op signed in; TF_TOKEN_terrakube_api_dominiksiejak_pl or credentials.tfrc.json
set -euo pipefail

VAULT="${OP_VAULT:-Servers}"
ITEM="${OP_ITEM:-terrakube-tofu}"
API="${TERRAKUBE_API:-https://terrakube-api.dominiksiejak.pl}"
ORG_NAME="${TERRAKUBE_ORG:-HomeLab}"

token() {
  if [ -n "${TF_TOKEN_terrakube_api_dominiksiejak_pl:-}" ]; then
    printf '%s' "$TF_TOKEN_terrakube_api_dominiksiejak_pl"
    return
  fi
  python3 -c "import json; print(json.load(open('$HOME/.terraform.d/credentials.tfrc.json'))['credentials']['terrakube-api.dominiksiejak.pl']['token'])"
}

TOKEN="$(token)"

python3 - "$TOKEN" "$API" "$ORG_NAME" "$VAULT" "$ITEM" <<'PY'
import json, subprocess, sys, urllib.request, urllib.error

TOKEN, API, ORG_NAME, VAULT, ITEM = sys.argv[1:]

def op_read(label):
  r = subprocess.run(
    ["op", "read", f"op://{VAULT}/{ITEM}/{label}"],
    capture_output=True, text=True, timeout=120,
  )
  if r.returncode != 0:
    return None
  return r.stdout.rstrip("\n")

def api(method, path, body=None):
  data = None if body is None else json.dumps(body).encode()
  headers = {"Authorization": f"Bearer {TOKEN}"}
  if body is not None:
    headers["Content-Type"] = "application/vnd.api+json"
  req = urllib.request.Request(f"{API}{path}", data=data, method=method, headers=headers)
  with urllib.request.urlopen(req, timeout=60) as resp:
    raw = resp.read()
    return json.loads(raw) if raw else None

WS_KEYS = {
  "adguard": [("adguard_username", "TERRAFORM"), ("adguard_password", "TERRAFORM")],
  "proxmox": [
    ("proxmox_api_token_id", "TERRAFORM"),
    ("proxmox_api_token_secret", "TERRAFORM"),
    ("proxmox_openid_client_secret", "TERRAFORM"),
  ],
  "backblaze": [("b2_application_key_id", "TERRAFORM"), ("b2_application_key", "TERRAFORM")],
  "gcp": [("gcp_project_id", "TERRAFORM"), ("GOOGLE_CREDENTIALS", "ENV")],
  "netbox": [("netbox_url", "TERRAFORM"), ("netbox_api_token", "TERRAFORM")],
  "gitea": [("gitea_username", "TERRAFORM"), ("gitea_password", "TERRAFORM"), ("github_token", "TERRAFORM")],
  "unifi": [
    ("unifi_username", "TERRAFORM"),
    ("unifi_password", "TERRAFORM"),
    ("wlan_passphrase_hass", "TERRAFORM"),
    ("wlan_passphrase_raval", "TERRAFORM"),
    ("device_ssh_username", "TERRAFORM"),
    ("device_ssh_password", "TERRAFORM"),
  ],
}

orgs = api("GET", "/api/v1/organization")
org_id = next(o["id"] for o in orgs["data"] if o["attributes"]["name"] == ORG_NAME)
org = api("GET", f"/api/v1/organization/{org_id}?include=workspace")
ws = {i["attributes"]["name"]: i["id"] for i in org["included"] if i["type"] == "workspace"}

for wname, keys in WS_KEYS.items():
  wid = ws.get(wname)
  if not wid:
    print(f"skip missing workspace {wname}")
    continue
  cur = api("GET", f"/api/v1/organization/{org_id}/workspace/{wid}?include=variable")
  existing = {}
  for i in cur.get("included") or []:
    if i["type"] != "variable":
      continue
    a = i["attributes"]
    existing[(a.get("category"), a.get("key"))] = i
  for key, cat in keys:
    val = op_read(key)
    if not val or val.startswith("REPLACE_ME"):
      print(f"{wname}: skip {cat}/{key} (placeholder/missing)")
      continue
    body = {
      "data": {
        "type": "variable",
        "attributes": {
          "key": key,
          "value": val,
          "sensitive": True,
          "hcl": False,
          "category": cat,
          "description": f"synced from 1Password {VAULT}/{ITEM}",
        },
      }
    }
    ex = existing.get((cat, key))
    try:
      if ex:
        body["data"]["id"] = ex["id"]
        api("PATCH", f"/api/v1/organization/{org_id}/workspace/{wid}/variable/{ex['id']}", body)
        print(f"{wname}: patched {cat}/{key}")
      else:
        api("POST", f"/api/v1/organization/{org_id}/workspace/{wid}/variable", body)
        print(f"{wname}: created {cat}/{key}")
    except urllib.error.HTTPError as e:
      print(f"{wname}: FAIL {cat}/{key} {e.code} {e.read()[:160].decode()}")
PY
