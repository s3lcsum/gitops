# ESO OpenBao Cutover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flip all application ExternalSecrets from `ClusterSecretStore/onepassword` to `ClusterSecretStore/openbao`, with secrets living at `secret/k8s/<item>`.

**Architecture:** One-shot copy of 1Password `Servers` item fields into OpenBao KV v2 under `k8s/<item>`. Rewrite ExternalSecret `secretStoreRef` + split `remoteRef.key` into path + `property`. Leave unseal, OpenBao OIDC, and the 1Password bootstrap ExternalSecret on `onepassword`.

**Tech Stack:** External Secrets Operator, OpenBao KV v2, 1Password CLI (`op`), kubectl context `k8s@lake`, AppRole writer (`~/.config/openbao/{role_id,secret_id}`).

**Spec:** `docs/superpowers/specs/2026-10-31-eso-openbao-cutover-design.md`

## Global Constraints

- Never flip `openbao-unseal`, `openbao-oidc`, or `external-secrets/onepassword` off 1Password.
- Never commit secret values, `*.env`, or real KV payloads.
- OpenBao path prefix is exactly `k8s/<item>` (not `terraform_env/`).
- ESO Vault remoteRef: `key` = path under mount `secret/`, `property` = map field.
- CNPG store `kubernetes-cnpg` unchanged (e.g. Sure `dbPassword` sourceRef stays).
- Cluster context: `k8s@lake`. OpenBao write API: `https://bao.dominiksiejak.pl`.

## File map

| Path | Role |
|---|---|
| `kubernetes/**/externalsecret*.yaml` + listed ES in other YAMLs | Flip store + remoteRef |
| `kubernetes/platform/external-secrets/resources/eso-stagger-refresh.yaml` | Comment: only remaining 1P ES |
| `AGENTS.md` | Document OpenBao as app secret source |
| (no committed upload script) | One-shot local Python in shell; discard after |

### Task 1: Verify OpenBao store + writer auth

**Files:** none (read-only probe)

**Interfaces:**
- Consumes: live cluster + AppRole files
- Produces: confirmed Ready store; writer can PUT `secret/data/k8s/_probe`

- [ ] **Step 1: Check ClusterSecretStore**

```bash
kubectl --context k8s@lake get clustersecretstore openbao onepassword
kubectl --context k8s@lake describe clustersecretstore openbao | tail -30
```

Expected: both `Valid` / Ready. `openbao` server `http://openbao.openbao.svc:8200`, role `eso-openbao`.

- [ ] **Step 2: Probe write with AppRole**

```bash
ROLE=$(tr -d '\n' < ~/.config/openbao/role_id)
SECRET=$(tr -d '\n' < ~/.config/openbao/secret_id)
TOKEN=$(curl -sS -X POST "https://bao.dominiksiejak.pl/v1/auth/approle/login" \
  -H 'Content-Type: application/json' \
  -d "{\"role_id\":\"$ROLE\",\"secret_id\":\"$SECRET\"}" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["auth"]["client_token"])')
curl -sS -X POST "https://bao.dominiksiejak.pl/v1/secret/data/k8s/_probe" \
  -H "X-Vault-Token: $TOKEN" -H 'Content-Type: application/json' \
  -d '{"data":{"ok":"1"}}'
curl -sS -X DELETE "https://bao.dominiksiejak.pl/v1/secret/metadata/k8s/_probe" \
  -H "X-Vault-Token: $TOKEN"
```

Expected: write returns `{"request_id":...}`; delete succeeds. If 403, terraform AppRole lacks write — use root token from 1Password `openbao` for upload only, then revoke session.

- [ ] **Step 3: Commit**

No code changes — skip commit.

---

### Task 2: Copy 1Password items → `secret/k8s/<item>`

**Files:** none committed (local one-shot only)

**Interfaces:**
- Consumes: 1Password vault `Servers`; writer token from Task 1
- Produces: OpenBao paths listed below with field maps

**Items to copy** (title = path suffix):

`argocd`, `sure`, `cloudflare`, `adguard`, `crowdsec-lapi`, `grafana`, `homepage`, `wealthfolio`, `netbox`, `hass`, `jellyfin`, `authentik`, `mktxp`

Do **not** copy into `k8s/` for ESO: rely on existing 1P for item `openbao` (unseal/oidc) and `k8s-external-secrets`.

- [ ] **Step 1: Run one-shot copy (local; do not commit output)**

```bash
python3 <<'PY'
import json, subprocess, urllib.request
from pathlib import Path

ITEMS = [
  "argocd", "sure", "cloudflare", "adguard", "crowdsec-lapi", "grafana",
  "homepage", "wealthfolio", "netbox", "hass", "jellyfin", "authentik", "mktxp",
]
ROLE = Path.home().joinpath(".config/openbao/role_id").read_text().strip()
SECRET = Path.home().joinpath(".config/openbao/secret_id").read_text().strip()
ADDR = "https://bao.dominiksiejak.pl"

def bao(method, path, body=None, token=None):
    data = None if body is None else json.dumps(body).encode()
    r = urllib.request.Request(ADDR + path, data=data, method=method)
    r.add_header("Content-Type", "application/json")
    if token:
        r.add_header("X-Vault-Token", token)
    with urllib.request.urlopen(r) as resp:
        return json.load(resp)

token = bao("POST", "/v1/auth/approle/login", {"role_id": ROLE, "secret_id": SECRET})["auth"]["client_token"]

def fields_from_op(title: str) -> dict:
    raw = subprocess.check_output(
        ["op", "item", "get", title, "--vault", "Servers", "--format=json"],
        text=True,
    )
    item = json.loads(raw)
    out = {}
    for f in item.get("fields", []):
        lab = f.get("label") or f.get("id")
        val = f.get("value")
        if not lab or val is None or lab in ("notesPlain",):
            continue
        # skip empty SECTION labels
        if f.get("type") == "TOTP":
            continue
        out[lab] = val
    return out

for title in ITEMS:
    try:
        data = fields_from_op(title)
    except subprocess.CalledProcessError as e:
        print(f"SKIP {title}: op failed {e}")
        continue
    if not data:
        print(f"SKIP {title}: no fields")
        continue
    bao("POST", f"/v1/secret/data/k8s/{title}", {"data": data}, token=token)
    print(f"OK k8s/{title} keys={sorted(data.keys())}")
PY
```

Expected: `OK k8s/<item> keys=[...]` for each item. Fix any `SKIP` (wrong title / vault) before continuing.

- [ ] **Step 2: Spot-check keys (no values)**

```bash
TOKEN=... # same login as above
for i in argocd sure cloudflare adguard crowdsec-lapi grafana homepage wealthfolio netbox hass jellyfin authentik mktxp; do
  echo "==== $i ===="
  curl -sS -H "X-Vault-Token: $TOKEN" \
    "https://bao.dominiksiejak.pl/v1/secret/data/k8s/$i" \
    | python3 -c 'import sys,json; d=json.load(sys.stdin)["data"]["data"]; print(sorted(d.keys()))'
done
```

Expected: keys match YAML field suffixes (e.g. sure has `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, `SECRET_KEY_BASE`, `db-password`, `OIDC_ISSUER`).

- [ ] **Step 3: Commit**

No git changes — skip.

---

### Task 3: Flip Sure + Argo CD ExternalSecrets

**Files:**
- Modify: `kubernetes/sure/resources/externalsecret.yaml`
- Modify: `kubernetes/argocd/resources/externalsecret-oidc.yaml`
- Modify: `kubernetes/argocd/resources/externalsecret-repo-creds.yaml`

**Interfaces:**
- Consumes: `secret/k8s/sure`, `secret/k8s/argocd`
- Produces: synced k8s Secrets for Sure + Argo CD OIDC/repo

- [ ] **Step 1: Rewrite `kubernetes/sure/resources/externalsecret.yaml`**

Both ExternalSecrets: `secretStoreRef.name: openbao`. Change remoteRefs:

```yaml
# sure-user
      remoteRef:
        key: k8s/sure
        property: db-password

# sure (keep kubernetes-cnpg sourceRef for dbPassword unchanged)
    - secretKey: secretKeyBase
      remoteRef:
        key: k8s/sure
        property: SECRET_KEY_BASE
    - secretKey: oidcClientId
      remoteRef:
        key: k8s/sure
        property: OIDC_CLIENT_ID
    - secretKey: oidcClientSecret
      remoteRef:
        key: k8s/sure
        property: OIDC_CLIENT_SECRET
    - secretKey: oidcIssuer
      remoteRef:
        key: k8s/sure
        property: OIDC_ISSUER
```

Update header comment to OpenBao `secret/k8s/sure`.

- [ ] **Step 2: Rewrite Argo CD ExternalSecrets**

`externalsecret-oidc.yaml`:

```yaml
  secretStoreRef:
    name: openbao
    kind: ClusterSecretStore
  data:
    - secretKey: oidc.authentik.clientSecret
      remoteRef:
        key: k8s/argocd
        property: oidc-client-secret
```

`externalsecret-repo-creds.yaml`: same store; `key: k8s/argocd`, `property: github-pat` (confirm field label via Task 2 spot-check — if 1P label differs, use exact label from OpenBao keys).

- [ ] **Step 3: Apply via Argo or kubectl and verify**

```bash
kubectl --context k8s@lake -n sure annotate externalsecret sure sure-user force-sync="$(date +%s)" --overwrite
kubectl --context k8s@lake -n argocd annotate externalsecret argocd-oidc argocd-repo-creds-github force-sync="$(date +%s)" --overwrite
kubectl --context k8s@lake get externalsecret -n sure
kubectl --context k8s@lake get externalsecret -n argocd
kubectl --context k8s@lake -n sure get secret sure -o jsonpath='{.data.OIDC_CLIENT_ID}' | base64 -d; echo
```

Expected: ExternalSecrets `SecretSynced`; Sure `OIDC_CLIENT_ID` prints `sure`.

- [ ] **Step 4: Commit**

```bash
git add kubernetes/sure/resources/externalsecret.yaml \
  kubernetes/argocd/resources/externalsecret-oidc.yaml \
  kubernetes/argocd/resources/externalsecret-repo-creds.yaml
git commit -m "$(cat <<'EOF'
feat(eso): point Sure and Argo CD ExternalSecrets at OpenBao.

EOF
)"
```

---

### Task 4: Flip networking + cert-manager ExternalSecrets

**Files:**
- Modify: `kubernetes/networking/cloudflared/resources/externalsecret.yaml`
- Modify: `kubernetes/networking/external-dns/resources/externalsecret-cloudflare.yaml`
- Modify: `kubernetes/networking/external-dns/resources/externalsecret-adguard.yaml`
- Modify: `kubernetes/networking/traefik/resources/externalsecret-crowdsec.yaml`
- Modify: `kubernetes/platform/cert-manager/resources/externalsecret.yaml`

**Interfaces:**
- Consumes: `k8s/cloudflare`, `k8s/adguard`, `k8s/crowdsec-lapi`
- Produces: synced tunnel/DNS/CrowdSec secrets

- [ ] **Step 1: Rewrite each file**

Pattern for every flipped ES in these files:

```yaml
  secretStoreRef:
    name: openbao
    kind: ClusterSecretStore
```

| File | property mapping |
|---|---|
| cloudflared | `key: k8s/cloudflare`, `property: tunnel-token` |
| external-dns cloudflare | `key: k8s/cloudflare`, `property: dns-token` |
| cert-manager | `key: k8s/cloudflare`, `property: dns-token` |
| external-dns adguard | `key: k8s/adguard`, `property: username` / `password` |
| crowdsec | `key: k8s/crowdsec-lapi`, `property: credential` |

- [ ] **Step 2: Force-sync and verify Ready**

```bash
for ns_es in cloudflared/cloudflared external-dns/cloudflare-api-token external-dns/adguard traefik/crowdsec-lapi cert-manager/cloudflare-api-token; do
  ns=${ns_es%/*}; es=${ns_es#*/}
  kubectl --context k8s@lake -n "$ns" annotate externalsecret "$es" force-sync="$(date +%s)" --overwrite
done
kubectl --context k8s@lake get externalsecret -A | grep -E 'cloudflared|external-dns|traefik|cert-manager'
```

Expected: status Ready / SecretSynced for each.

- [ ] **Step 3: Commit**

```bash
git add kubernetes/networking/cloudflared/resources/externalsecret.yaml \
  kubernetes/networking/external-dns/resources/externalsecret-cloudflare.yaml \
  kubernetes/networking/external-dns/resources/externalsecret-adguard.yaml \
  kubernetes/networking/traefik/resources/externalsecret-crowdsec.yaml \
  kubernetes/platform/cert-manager/resources/externalsecret.yaml
git commit -m "$(cat <<'EOF'
feat(eso): point edge DNS/tunnel/CrowdSec ExternalSecrets at OpenBao.

EOF
)"
```

---

### Task 5: Flip workload ExternalSecrets

**Files:**
- Modify: `kubernetes/workloads/homepage/resources/externalsecret.yaml`
- Modify: `kubernetes/workloads/wealthfolio/resources/externalsecret.yaml`
- Modify: `kubernetes/workloads/netbox/resources/externalsecret.yaml`
- Modify: `kubernetes/workloads/netbox/resources/database.yaml` (netbox-user ES only)
- Modify: `kubernetes/workloads/hass/resources/externalsecret.yaml`
- Modify: `kubernetes/workloads/mediabox/resources/externalsecret-jellyfin-sso.yaml`
- Modify: `kubernetes/workloads/mediabox/resources/externalsecret-gluetun.yaml`
- Modify: `kubernetes/platform/grafana-synthetic-agent/resources/externalsecret.yaml`
- Modify: `kubernetes/platform/authentik/resources/ldap-outpost.yaml` (ES only)
- Modify: `kubernetes/platform/authentik/resources/radius-outpost.yaml` (ES only)
- Modify: `kubernetes/platform/monitoring/resources/mktxp.yaml` (ES only)

**Interfaces:**
- Consumes: matching `k8s/<item>` paths from Task 2
- Produces: all remaining app ExternalSecrets on `openbao`

- [ ] **Step 1: Mechanical rewrite**

For every `remoteRef.key: <item>/<field>` under these files:

1. Set `secretStoreRef.name: openbao`
2. Replace with:

```yaml
      remoteRef:
        key: k8s/<item>
        property: <field>
```

Examples: `homepage/HOMEPAGE_VAR_HASS_TOKEN` → `key: k8s/homepage`, `property: HOMEPAGE_VAR_HASS_TOKEN`; `authentik/ldap-token` → `k8s/authentik` + `ldap-token`; `jellyfin/OIDC_CLIENT_SECRET` → `k8s/jellyfin` + `OIDC_CLIENT_SECRET`; `mktxp/username` → `k8s/mktxp` + `username`.

Leave non-ExternalSecret resources in those files untouched.

- [ ] **Step 2: Force-sync all flipped ES in these namespaces**

```bash
kubectl --context k8s@lake get externalsecret -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,STORE:.spec.secretStoreRef.name' \
  | awk '$3=="openbao" {print}'
kubectl --context k8s@lake get externalsecret -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,STORE:.spec.secretStoreRef.name,STATUS:.status.conditions[0].reason' \
  | awk '$3=="openbao"'
```

Expected: every `openbao` row shows `SecretSynced` (or Ready). Fix any `SecretSyncedError` by comparing OpenBao keys vs `property`.

- [ ] **Step 3: Commit**

```bash
git add kubernetes/workloads/homepage/resources/externalsecret.yaml \
  kubernetes/workloads/wealthfolio/resources/externalsecret.yaml \
  kubernetes/workloads/netbox/resources/externalsecret.yaml \
  kubernetes/workloads/netbox/resources/database.yaml \
  kubernetes/workloads/hass/resources/externalsecret.yaml \
  kubernetes/workloads/mediabox/resources/externalsecret-jellyfin-sso.yaml \
  kubernetes/platform/grafana-synthetic-agent/resources/externalsecret.yaml \
  kubernetes/platform/authentik/resources/ldap-outpost.yaml \
  kubernetes/platform/authentik/resources/radius-outpost.yaml \
  kubernetes/platform/monitoring/resources/mktxp.yaml
git commit -m "$(cat <<'EOF'
feat(eso): point remaining app ExternalSecrets at OpenBao.

EOF
)"
```

---

### Task 6: Docs + stagger CronJob note + final gate

**Files:**
- Modify: `AGENTS.md`
- Modify: `kubernetes/platform/external-secrets/resources/eso-stagger-refresh.yaml` (header comment only)
- Modify: `kubernetes/platform/openbao/resources/bootstrap-notes.yaml` (optional one-liner that apps use `k8s/`)

**Interfaces:**
- Consumes: completed flip
- Produces: docs match live wiring; only three 1P ExternalSecrets remain

- [ ] **Step 1: Update AGENTS.md Data and secrets bullet**

Replace the ESO/1Password sentence with:

```markdown
- K8s app secrets: OpenBao KV `secret/k8s/<item>` via ExternalSecrets (`ClusterSecretStore/openbao`, SA `eso-openbao`). 1Password remains only for OpenBao unseal + OpenBao OIDC UI client + `ClusterSecretStore/onepassword` bootstrap token (`external-secrets/onepassword`). Day-2 OpenBao API config still `tofu/openbao`.
```

- [ ] **Step 2: Comment on stagger CronJob**

At top of `eso-stagger-refresh.yaml`, note it only force-syncs ExternalSecrets still on store `onepassword` (unseal / oidc / bootstrap). No code change required if filter already selects `onepassword`.

- [ ] **Step 3: Final inventory gate**

```bash
kubectl --context k8s@lake get externalsecret -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,STORE:.spec.secretStoreRef.name' \
  | awk '$3=="onepassword" {print}'
```

Expected exactly:

```
openbao            openbao-unseal
openbao            openbao-oidc
external-secrets   onepassword
```

```bash
kubectl --context k8s@lake get externalsecret -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,STORE:.spec.secretStoreRef.name,REASON:.status.conditions[0].reason' \
  | awk '$3=="openbao" && $4!="SecretSynced" {print}'
```

Expected: empty.

Smoke: open `https://sure.dominiksiejak.pl` OIDC login; Argo CD UI still loads.

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md \
  kubernetes/platform/external-secrets/resources/eso-stagger-refresh.yaml \
  kubernetes/platform/openbao/resources/bootstrap-notes.yaml
git commit -m "$(cat <<'EOF'
docs(eso): record OpenBao as app secret store; 1P chicken-egg only.

EOF
)"
```

---

## Spec coverage (self-review)

| Spec requirement | Task |
|---|---|
| Stay on 1P: unseal / oidc / bootstrap | Global Constraints + Task 6 gate |
| KV `k8s/<item>` + property fields | Tasks 2–5 |
| Flip inventory rows | Tasks 3–5 |
| Data copy from 1P | Task 2 |
| Stagger CronJob / AGENTS | Task 6 |
| Rollback via git + 1P | Implied (no delete 1P items) |
| Success criteria Ready + three 1P left | Task 6 Step 3 |

Placeholder scan: none. Field labels must match Task 2 spot-check (especially `github-pat` / CrowdSec `credential`).
