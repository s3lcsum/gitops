# Jellyfin Authentik LDAP + OIDC Auth — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Authenticate `jellyfin.dominiksiejak.pl` users via Authentik through both an OIDC SSO login button and a legacy LDAP username/password login.

**Architecture:** Two Jellyfin community plugins (Flowfin SSO for OIDC, official LDAP-Auth for LDAP) deployed as *checked-in bind-mounted* binaries under `stacks/mediabox/jellyfin-plugins/`, configured post-deploy over the Jellyfin admin API (secrets injected at apply time, never committed). Authentik side: `groups` scope mapping added to the existing `jellyfin` OAuth2 app, plus a `svc_jellyfin` service account + `search_group` on the existing shared LDAP provider.

**Tech Stack:** OpenTofu (`terraform/authentik`, `terraform/portainer`), Docker Compose (Portainer string-method), Jellyfin 10.11.11, curl + jq against the Jellyfin admin API, `make sync-portainer`, Vault/gitignored env for secrets.

## Global Constraints

- **Deploy path only:** every change ships as repo content → `make` targets → `tofu apply` on `authentik` (Terraform Cloud workspace `gitops-authentik`) and `portainer` workspaces. **No direct container/UI access.**
- `portainer_stack` is string-method: no `build:`, no host commands — plugin binaries MUST come from an absolute-host-path bind mount under `/opt/mediabox/`.
- Jellyfin `/config` is the named volume `jellyfin_config`; the *plugins* directory is shadowed by the bind mount at `/config/plugins`. Do NOT bind-mount `/config/config` wholesale.
- `make sync-portainer` rsyncs `stacks/` → `portainer:/opt` with `--delete`; it runs automatically as a prerequisite of the portainer `apply` target.
- Secrets (OIDC client_secret, LDAP svc password, Jellyfin admin API key) must never be committed. They come from gitignored env (`stacks/mediabox/.jellyfin.secrets` → generated at seed time) or Vault.
- Jellyfin provider name in the SSO plugin MUST be exactly `authentik` (lowercase) to match the registered redirect `/sso/OID/redirect/authentik`.
- Default Authentik oauth2 `property_mappings` (`data.tf`) are only `openid|profile|email` scope — `groups` scope must be added explicitly.
- Pre-commit hooks: `end-of-file-fixer`, `OpenTofu format`.

---

### Task 1: Register `svc_jellyfin` service account + `groups` scope mapping in Authentik (Terraform)

**Files:**
- Modify: `terraform/authentik/variables.tf`, `terraform/authentik/defaults.auto.tfvars`
- Modify: `terraform/authentik/identity.tf` (service-account wiring — verify `var.service_accounts` shape first)
- Modify: `terraform/authentik/applications.tf` (add a `groups` scope mapping + attach to jellyfin provider)
- Verify: `terraform/authentik/locals.tf` enh.

**Interfaces:**
- Consumes: `authentik_group.admins.id`, `authentik_group.users.id`, `authentik_provider_oauth2.oauth2["jellyfin"]` (existing).
- Produces: `authentik_property_mapping_provider_scope.jellyfin_groups.id` (scope name `groups`, expression returning group names), and `svc_jellyfin` user + token consumed by Task 4.

- [ ] **Step 1: Read the current variables/defaults to match conventions**

Read `terraform/authentik/variables.tf` and `terraform/authentik/defaults.auto.tfvars`. Confirm whether `var.service_accounts` already exists (identity.reads it). If `svc_jellyfin` already exists elsewhere, skip its creation and reuse.

- [ ] **Step 2: Add the `groups` scope mapping resource to `applications.tf`**

Append after the `authentik_property_mapping_provider_scope.custom_claims` block:

```hcl
# OIDC scope mapping returning Authentik group names. The Filefin SSO plugin
# requests the "groups" scope to implement role/group-based admission.
resource "authentik_property_mapping_provider_scope" "jellyfin_groups" {
  name       = "jellyfin-groups"
  scope_name = "groups"
  expression = "return [group.name for group in user.ak_groups.all()]"
}
```

**Note:** `custom_claims` uses `scope_name = each.key` (e.g. `jellyfin`); here we need an explicit `groups` scope name, hence a dedicated resource. Remove any unwanted `mapping` key from `local.oauth2_applications.jellyfin` if present.

- [ ] **Step 3: Attach the `groups` mapping to the jellyfin provider**

In `applications.tf`, extend the `authentik_provider_oauth2.oauth2` resource for the `jellyfin` key so its `property_mappings` include the new mapping. Since other apps share that resource, wrap with a local variable. Add to `locals`:

```hcl
  jellyfin_scope_ids = concat(
    data.authentik_property_mapping_provider_scope.oauth2_scopes.ids,
    [authentik_property_mapping_provider_scope.jellyfin_groups.id]
  )
```

and in the `authentik_provider_oauth2.oauth2` block replace `property_mappings` with:

```hcl
  property_mappings = each.key == "jellyfin" ? (
    lookup(each.value, "mapping", null) != null
      ? concat(local.jellyfin_scope_ids, [authentik_property_mapping_provider_scope.custom_claims["jellyfin"].id])
      : local.jellyfin_scope_ids
  ) : (
    lookup(each.value, "mapping", null) != null
      ? concat(data.authentik_property_mapping_provider_scope.oauth2_scopes.ids, [authentik_property_mapping_provider_scope.custom_claims[each.key].id])
      : data.authentik_property_mapping_provider_scope.oauth2_scopes.ids
  )
```

- [ ] **Step 4: Add `svc_jellyfin` service account + its app_password token**

Add to `defaults.auto.tfvars` (gitignored — verified against `.gitignore` in Task 0; if the file is committed, use a new `override.tfvars.json` family instead):

```hcl
service_accounts = {
  svc_jellyfin = {
    name     = "Jellyfin LDAP service account"
    is_admin = false
  }
}
```

(Reuse the existing `authentik_user.service_accounts` + `authentik_token.service_account_tokens` resources — they already emit an `app_password`-intent token that doubles as the LDAP bind password for `svc_jellyfin`.)

Add the service account to a designated group so `search_group` on the provider can gate it. Append to `identity.tf`:

```hcl
resource "authentik_group" "svc" {
  name         = "svc"
  is_superuser = false
}

resource "authentik_group_user" "svc_jellyfin_svc" {
  user  = authentik_user.service_accounts["svc_jellyfin"].id
  group = authentik_group.svc.id
}
```

- [ ] **Step 5: Set `search_group` on the LDAP provider**

In `ldap.tf`, add to `authentik_provider_ldap.ldap`:

```hcl
  search_group = authentik_group.svc.id
```

- [ ] **Step 6: `tofu validate` + `tofu plan`**

Run from `terraform/authentik/`: `tofu plan`, expect a planned change set that *only* adds the svc account/group + scope mapping, and does NOT otherwise modify other apps (`jellyfin` grants/redirect unchanged). Do NOT apply yet (applies happen per-workspace in Task 7 after review).

- [ ] **Step 7: Apply & commit**

```bash
tofu apply -auto-approve   # uses Terraform Cloud workspace gitops-authentik
```

Confirm `jellyfin` provider now carries the `groups` scope. Commit:

```bash
git add terraform  # terraform/authentik editors only
git commit -m "feat(authentik): jellyfin groups scope + LDAP svc account"
```

---

### Task 2: Seed the Jellyfin plugin binaries into the repo (checked-in bind tree)

**Files:**
- Create: `stacks/mediabox/jellyfin-plugins/ldapauth/…/Jellyfin.Plugin.LdapAuth.dll`
- Create: `stacks/mediabox/jellyfin-plugins/Jellyfin.Plugin.SSO/<version>/…`

**Interfaces:**
- Consumes: plugin releases from GitHub (Flowfin SSO, jellyfin LDAP).
- Produces: `/opt/mediabox/jellyfin-plugins` tree that Task 3 bind-mounts.

- [ ] **Step 1: Fetch official plugin repos/sources**

```bash
mkdir -p stacks/mediabox/jellyfin-plugins
curl -fsSL https://raw.githubusercontent.com/jellyfin/jellyfin-plugin-ldapauth/master/LDAP-Auth/Jellyfin.Plugin.LdapAuth/plugin.json \
  -o /tmp/ldap-plugin.json 2>/dev/null || true
# Pin the Jellyfin 10.11-compatible release from the Flowfin manifest
curl -fsSL https://raw.githubusercontent.com/Flowfin/jellyfin-plugin-sso/manifest-beta/manifest.json \
  -o /tmp/jellyfin-sso-manifest.json
```

(If raw.githubusercontent is blocked from this Mac, run these downloads on the `portainer` host via `ssh portainer`.)

- [ ] **Step 2: Locate the 10.11 build of the SSO plugin**

```bash
python3 - <<'PY'
import json
m = json.load(open("/tmp/jellyfin-sso-manifest.json"))
for v in reversed(m["versions"]):
    abi = v.get("targetAbi") or ""
    if abi.startswith("10.11."):
        print("version:", v["version"], "abi:", abi, "url:", v["url"])
        break
PY
```

Record the printed `version` and `url`. Expected: a release tag of the form `4.x` with `targetAbi` `10.11.*`.

- [ ] **Step 3: Download + extract SSO plugin into the repo layout**

Jellyfin loads plugins from `<config>/plugins/<PluginName>/<version>/<dll>`. Extract the zip so it mirrors that.

```bash
curl -fsSL -o /tmp/sso.zip "$SSO_URL"
unzip -o /tmp/sso.zip -d /tmp/sso-extract
mkdir -p "stacks/mediabox/jellyfin-plugins/Jellyfin.Plugin.SSO/$SSO_VERSION"
cp -r /tmp/sso-extract/Jellyfin.Plugin.SSO/* "stacks/mediabox/jellyfin-plugins/Jellyfin.Plugin.SSO/$SSO_VERSION/"
ls -R stacks/mediabox/jellyfin-plugins/Jellyfin.Plugin.SSO
```

Expected: the version folder contains `Jellyfin.Plugin.SSO.dll` (+ manifest `.meta`/`.json`).

- [ ] **Step 4: Download + extract the LDAP plugin**

The official LDAP plugin ships a single DLL. Resolve the latest 10.11-compatible release and extract it:

```bash
curl -fsSL "https://api.github.com/repos/jellyfin/jellyfin-plugin-ldapauth/releases" -o /tmp/ldap-releases.json
python3 - <<'PY'
import json, urllib.request
rel = json.load(open("/tmp/ldap-releases.json"))
# pick newest 10.11-targeted release, prefer a Jellyfin.Plugin.LdapAuth zip asset
target = next(r for r in rel if any("LdapAuth" in a["name"] for a in r.get("assets", [])))
asset  = next(a for a in target["assets"] if "LdapAuth" in a["name"] and a["name"].endswith((".zip", ".tar.gz")))
print(asset["browser_download_url"])
PY
```

Download that URL and extract the single `Jellyfin.Plugin.LdapAuth.dll` so the repo tree is:

```
stacks/mediabox/jellyfin-plugins/ldapauth/Jellyfin.Plugin.LdapAuth.dll
```

- [ ] **Step 5: Commit plugin binaries**

```bash
git add stacks/mediabox/jellyfin-plugins
git commit -m "feat(mediabox): jellyfin SSO + LDAP plugin binaries"
```

(Note: git large-binary handling ok — both dlls are < 5 MB; pre-commit forbids files > 5 MB.)

---

### Task 3: Bind-mount plugins + config in `mediabox` compose

**Files:**
- Modify: `stacks/mediabox/compose.yaml` (jellyfin service)

**Interfaces:**
- Consumes: Task 2's `stacks/mediabox/jellyfin-plugins/`.
- Produces: container `jellyfin` with `/config/plugins` bound to `/opt/mediabox/jellyfin-plugins`.

- [ ] **Step 1: Add the bind volume to the jellyfin service**

In `stacks/mediabox/compose.yaml`, in the `jellyfin` service `volumes:` section add:

```yaml
      - /opt/mediabox/jellyfin-plugins:/config/plugins
```

(Make sure it is under the `jellyfin:` service, indented consistently, and that `/opt/mediabox/jellyfin-plugins` exists after `make sync-portainer`.)

- [ ] **Step 2: Verify compose is valid YAML**

```bash
docker compose -f stacks/mediabox/compose.yaml config -q   # from git root
```

- [ ] **Step 3: Sync + apply the portainer workspace**

```bash
cd terraform/portainer
make sync-portainer   # rsyncs stacks/ -> portainer:/opt
tofu plan             # expect only mediabox stack update
```

Do not `apply` yet — that happens once in the deploy step of Task 6 (plugins need config set between restarts).

- [ ] **Step 4: Commit compose change**

```bash
git add stacks/mediabox/compose.yaml
git commit -m "chore(mediabox): bind jellyfin plugins"
```

---

### Task 4: Configure the plugin over the Jellyfin admin API

**Prerequisite (operator step, not automated):** an admin API key. Documented in `stacks/mediabox/README` (create your own via Dashboard → API keys, or reissue from `secrets`). It is consumed only at apply time from env, never committed.

**Files:**
- Create: `stacks/mediabox/scripts/jellyfin-api.sh` (helper: `JF_API_KEY`, `JF_BASE=https://jellyfin.dominiksiejak.pl`, curl wrapper)
- Create: `stacks/mediabox/scripts/configure-jellyfin-auth.sh`
- Create: `stacks/mediabox/.jellyfin.secrets.example`
- Modify: `stacks/mediabox/README.md`

**Interfaces:**
- Consumes: plugin IDs from Task 2 installs; OIDC client_id/secret + LDAP svc password.
- Produces: SSO + LDAP plugins configured on the running server.

- [ ] **Step 1: Write the helper + secret template**

`stacks/mediabox/scripts/jellyfin-plugin.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

JF_BASE="${JF_BASE:-https://jellyfin.dominiksiejak.pl}"
JF_API_KEY="${JF_API_KEY:?set JF_API_KEY}"

jf_api() { # jf_api GET|POST /path [json]
  local method="$1" path="$2" data="${3:-}"
  curl -fsS -X "$method" "$JF_BASE$path" \
    -H "X-Emby-Token: $JF_API_KEY" \
    -H "Accept: application/json" \
    "${data:+ -H 'Content-Type: application/json' -d '$data'}"
}

plugin_id() { # plugin_id NAME  -> plugin GUID
  jf_api GET "/Plugins" | python3 -c \
    "import sys,json; [print(p['Id']) for p in json.load(sys.stdin) if p['Name']=='$1']"
}
```

`.jellyfin.secrets.example` (gitignored):

```
JF_API_KEY=
OIDC_CLIENT_SECRET=
LDAP_SVC_PASSWORD=
```

- [ ] **Step 2: (Re)start jellyfin with bind-mount loaded; confirm plugins keyed**

First do the compose apply from Task 3:

```bash
cd terraform/portainer
make sync-portainer && tofu apply -auto-approve
```

Then confirm both plugins loaded:

```bash
ssh portainer 'docker exec jellyfin curl -fsS localhost:8096/Plugins -H "X-Emby-Token: '"$JF_API_KEY"'"' | \
  jq -r '.[] | select(.Name|test("LDAP|SSO")) | .Name'
```

Expected: two listing entries (`LDAP-Auth`, `SSO-Auth`).

- [ ] **Step 3: Capture current plugin configurations**

```bash
for name in "LDAP-Auth" "SSO-Auth"; do
  id=$(plugin_id "$name")
  printf '%s: %s\n' "$name" "$id"
  jf_api GET "/Plugins/$id/Configuration"
done
```

(Note each plugin's exact JSON shape into the task's implementation note; field names below follow the official plugin config `Option[]` conventions for Jellyfin 10.11.)

- [ ] **Step 4: Write LDAP config via admin API**

Using the actual JSON from Step 3, set at least:

```json
{
  "IsEnabled": true,
  "LdapServer": "192.168.89.253",
  "Port": 389,
  "IsLdaps": false,
  "BaseDn": "dc=dominiksiejak,dc=pl",
  "SearchBase": "ou=users,dc=dominiksiejak,dc=pl",
  "UsernameAttribute": "uid",
  "LdapUserFilter": "(objectClass=user)",
  "LdapAdminFilter": "(memberOf=cn=admins,ou=groups,dc=dominiksiejak,dc=pl)",
  "LdapAuthentication": true
}
```

Issue the update:

```bash
jf_api GET "/Plugins/$LDAP_ID/Configuration" > /tmp/ldapcfg.json
# edit the fields in /tmp/ldapcfg.json per the note above (keep unknown keys as-is)
jf_api POST "/Plugins/$LDAP_ID/Configuration" "$(cat /tmp/ldapcfg.json)"
```

(Exact playloads may include `IsEnabled` etc.—follow the discovered schema; do NOT blindly overwrite.)

- [ ] **Step 5: Write SSO (Flowfin) plugin config via admin API**

Set a single provider named exactly `authentik`:

```json
{
  "Providers": [{
    "Enabled": true,
    "OidEndpoint": "https://auth.dominiksiejak.pl/application/o/jellyfin",
    "OidClientId": "jellyfin",
    "OidSecret": "$OIDC_CLIENT_SECRET",
    "OidScopes": ["openid", "profile", "email", "groups"],
    "RoleClaim": "groups",
    "Roles": ["users"],
    "AdminRoles": ["admins"],
    "EnableAuthorization": true,
    "EnableAllFolders": true
  }]
}
```

Apply the same GET→jq-set→POST pattern as Step 4. The plugin AES-encrypts `OidSecret` at rest.

- [ ] **Step 6: Commit the scripts + seed template**

```bash
git add stacks/mediabox/scripts stacks/mediabox/.jellyfin.secrets.example
git commit -m "feat(mediabox): jellyfin api-based plugin config scripts"
```

---

### Task 5: End-to-end verification (LDAP then SSO)

**Interfaces:** Uses the configured plugins + Authentik.

- [ ] **Step 1: LDAP smoke test against the outpost**

On the workstation:

```bash
# confirm svc account can search (search_group working)
ldapsearch -x -H ldap://192.168.89.253:389 \
  -D "cn=svc_jellyfin,ou=users,dc=dominiksiejak,dc=pl" \
  -w "$LDAP_SVC_PASSWORD" -b "dc=dominiksiejak,dc=pl" \
  "(uid=s3lcsum)"
```

Expected: the `dreewniak@gmail.com` user object returned.

- [ ] **Step 2: Browser login test — LDAP legacy path**

Using the opencode Playwright MCP, navigate to `https://jellyfin.dominiksiejak.pl/web/`, click Manual Login, enter username `s3lcsum` + LDAP password → expect the web dashboard to open.

- [ ] **Step 3: Browser login test — OIDC SSO path**

From the login page, click **Sign in with authentik** → redirect to `auth.dominiksiejak.pl` → approve → return to jellyfin dashboard. Confirm the user == the same Authentik identity (same `s3lcsum` username).

- [ ] **Step 4: Record evidence + update docs**

Capture screenshots into `docs/` runbook `docs/runbooks/jellyfin-authentik-auth.md`, plus the exact wire outputs (search bind, API responses) recorded as context.

- [ ] **Step 5: Final commit (scripts + docs + spec-delta)**

```bash
git add docs
git commit -m "docs(mediabox): jellyfin-authentik auth runbook"
```

---

### Task 6: Rollback plan documentation (no code)

- [ ] **Step 1: Write `docs/runbooks/jellyfin-authentik-rollback.md`**

Rollback = remove the two bind volumes from compose + `tofu apply` (portainer) + remove the SV call/mapping in authentik TF + `tofu apply`. Document that `jellyfin_config` volume is untouched except plugin runtime state.

- [ ] **Step 2: Commit**

```bash
git commit -am "docs(mediabox): jellyfin authentik rollback runbook"
```

---

## Verification summary

- `tofu plan/apply` on `authentik` (new scope mapping + svc account, no unexpected diffs)
- `tofu plan/apply` on `portainer` (mediabox bind mount)
- `docker compose config -q` clean
- API `GET /Plugins` lists both plugins loaded
- LDAP bind+search via `ldap` CLI and a real Playwright login with `s3lcsum`
- Playwright SSO round-trip via `auth.dominiksiejak.pl`
