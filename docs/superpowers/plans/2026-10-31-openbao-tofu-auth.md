# OpenBao OpenTofu Auth & Policies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Manage OpenBao engines/policies/auth via `terraform/openbao`, fix OIDC default role `admin` for blank UI Role login, and share one AppRole credential set across local / Terrakube / future GHA (K8s auth remains for ESO).

**Architecture:** One-shot root bootstrap creates AppRole `terraform` + 1Password fields. HashiCorp `vault` provider (against OpenBao at `https://openbao.dominiksiejak.pl`) then owns KV `secret/`, policies, OIDC, Kubernetes role `eso-openbao`, and AppRole role definition. Authentik gains an OpenBao `groups` scope mapping for later; v1 still hard-binds OIDC role → policy `admin`.

**Tech Stack:** OpenTofu `>= 1.11.5` (pin `1.12.5`), provider `hashicorp/vault` `5.13.0`, OpenBao `2.7.1`, Authentik OpenTofu module, Terrakube org `HomeLab` workspace `openbao`.

**Spec:** `docs/superpowers/specs/2026-10-31-openbao-tofu-auth-design.md`

## Global Constraints

- OpenTofu, not Terraform; pin providers to exact versions (never `~>`)
- Backend: Terrakube `terrakube-api.dominiksiejak.pl` / org `HomeLab` / workspace `openbao`
- Provider address: `https://openbao.dominiksiejak.pl` only (no ClusterIP for local/GHA/Terrakube)
- Never commit `*.tfvars`, root token, AppRole ids, OIDC client secret
- Do not resurrect `terraform/vault`; do not flip any ExternalSecret off `onepassword`
- Do not ship a new GHA tofu workflow in this cut
- AppRole secret_id is created once outside state (CLI/bootstrap); tofu must not manage a regenerating `vault_approle_auth_backend_role_secret_id` resource
- Kubernetes auth TokenReview runs **inside** OpenBao pods → `kubernetes_host=https://kubernetes.default.svc:443`; omit reviewer JWT so OpenBao uses its local SA (chart `authDelegator` already on)
- Path note: live tree is `kubernetes/platform/openbao/` (not `kubernetes/openbao/`)

## File map

| Path | Role |
|------|------|
| `terraform/openbao/providers.tf` | Backend + vault provider + AppRole login |
| `terraform/openbao/variables.tf` | Addr, AppRole ids, OIDC client id/secret |
| `terraform/openbao/defaults.auto.tfvars.example` | Non-secret placeholders |
| `terraform/openbao/Makefile` | Includes `terraform/base.Makefile` |
| `terraform/openbao/policies.tf` | `admin`, `eso-read`, `terraform` |
| `terraform/openbao/secrets.tf` | KV v2 mount `secret` |
| `terraform/openbao/auth_oidc.tf` | OIDC backend + role `admin` + `default_role` |
| `terraform/openbao/auth_kubernetes.tf` | K8s backend + config + role `eso-openbao` |
| `terraform/openbao/auth_approle.tf` | AppRole backend + role `terraform` (no secret_id resource) |
| `terraform/authentik/applications.tf` | OpenBao `groups` scope mapping |
| `kubernetes/platform/openbao/resources/bootstrap-notes.yaml` | AppRole chicken-egg + point day-2 at tofu |
| `AGENTS.md` | Short note: `terraform/openbao` owns Bao API config |

---

### Task 1: Authentik OpenBao `groups` scope

**Files:**
- Modify: `terraform/authentik/applications.tf`

**Interfaces:**
- Consumes: existing `authentik_provider_oauth2.oauth2["openbao"]` property_mappings concat
- Produces: `authentik_property_mapping_provider_scope.openbao_groups` attached when `each.key == "openbao"`

- [ ] **Step 1: Add mapping resource after `argocd_groups`**

```hcl
resource "authentik_property_mapping_provider_scope" "openbao_groups" {
  name       = "openbao-groups"
  scope_name = "groups"
  expression = "return [g.name for g in request.user.ak_groups.all()]"
}
```

- [ ] **Step 2: Attach in `property_mappings` concat**

Add this line next to the other app-specific mappings:

```hcl
    each.key == "openbao" ? [authentik_property_mapping_provider_scope.openbao_groups.id] : [],
```

- [ ] **Step 3: Plan authentik module**

Run from `terraform/authentik/`:

```bash
make check
tofu plan
```

Expected: create `authentik_property_mapping_provider_scope.openbao_groups` and update `authentik_provider_oauth2.oauth2["openbao"]` mappings only (no destroy of the OpenBao app).

- [ ] **Step 4: Apply via Terrakube UI (or local apply if that is how this workspace is operated)**

Expected: OpenBao provider lists `groups` among scopes; OIDC tokens can include `groups` claim (unused by OpenBao policies in v1).

- [ ] **Step 5: Commit**

```bash
git add terraform/authentik/applications.tf
git commit -m "$(cat <<'EOF'
Add Authentik groups scope mapping for OpenBao OIDC.

EOF
)"
```

---

### Task 2: Scaffold `terraform/openbao` module shell

**Files:**
- Create: `terraform/openbao/providers.tf`
- Create: `terraform/openbao/variables.tf`
- Create: `terraform/openbao/defaults.auto.tfvars.example`
- Create: `terraform/openbao/Makefile`

**Interfaces:**
- Produces: Terrakube workspace name `openbao`; provider auth via AppRole vars
- Consumes: later tasks add resources into this module

- [ ] **Step 1: Write `providers.tf`**

```hcl
terraform {
  required_version = ">= 1.11.5"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.13.0"
    }
  }

  backend "remote" {
    hostname     = "terrakube-api.dominiksiejak.pl"
    organization = "HomeLab"
    workspaces {
      name = "openbao"
    }
  }
}

provider "vault" {
  address = var.vault_addr

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.approle_role_id
      secret_id = var.approle_secret_id
    }
  }
}
```

- [ ] **Step 2: Write `variables.tf`**

```hcl
variable "vault_addr" {
  type        = string
  description = "OpenBao API address (HTTPS)."
  default     = "https://openbao.dominiksiejak.pl"
}

variable "approle_role_id" {
  type        = string
  description = "AppRole role_id for tofu (1Password openbao/approle-role-id)."
  sensitive   = true
}

variable "approle_secret_id" {
  type        = string
  description = "AppRole secret_id for tofu (1Password openbao/approle-secret-id)."
  sensitive   = true
}

variable "oidc_client_id" {
  type        = string
  description = "Authentik OpenBao OAuth client id (1Password openbao/oidc-client-id)."
  sensitive   = true
}

variable "oidc_client_secret" {
  type        = string
  description = "Authentik OpenBao OAuth client secret (1Password openbao/oidc-client-secret)."
  sensitive   = true
}
```

- [ ] **Step 3: Write `defaults.auto.tfvars.example`**

```hcl
vault_addr         = "https://openbao.dominiksiejak.pl"
approle_role_id    = "from-1password"
approle_secret_id  = "from-1password"
oidc_client_id     = "from-1password"
oidc_client_secret = "from-1password"
```

- [ ] **Step 4: Write `Makefile`**

```makefile
#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile
```

- [ ] **Step 5: Create Terrakube workspace (manual, not in git)**

In Terrakube UI org `HomeLab`: create workspace `openbao` VCS-linked to this repo path `terraform/openbao` (same pattern as `grafana` / `adguard`). Add sensitive ENV / terraform vars: `approle_role_id`, `approle_secret_id`, `oidc_client_id`, `oidc_client_secret` (fill after Task 3 bootstrap). Optional: `vault_addr` if not using default.

- [ ] **Step 6: Commit scaffold (no secrets)**

```bash
git add terraform/openbao/providers.tf terraform/openbao/variables.tf \
  terraform/openbao/defaults.auto.tfvars.example terraform/openbao/Makefile
git commit -m "$(cat <<'EOF'
Scaffold terraform/openbao Terrakube module shell.

EOF
)"
```

---

### Task 3: One-shot AppRole bootstrap (root token)

**Files:**
- Modify: `kubernetes/platform/openbao/resources/bootstrap-notes.yaml` (runbook text; full rewrite of day-2 sections happens in Task 7 — here only ensure AppRole chicken-egg commands exist before first tofu apply)

**Interfaces:**
- Produces: auth mount `approle/`, policy `terraform`, role `terraform`, 1Password fields `approle-role-id` / `approle-secret-id` / confirm `root-token`
- Consumes: root token from 1Password `Servers` / `openbao`

- [ ] **Step 1: Login with root**

```bash
export VAULT_ADDR=https://openbao.dominiksiejak.pl
export VAULT_TOKEN='<root-token-from-1password>'
bao token lookup
```

Expected: display_name / policies include `root`.

If CLI against remote fails TLS/DNS, use:

```bash
kubectl --context k8s@lake -n openbao exec -it openbao-0 -- sh
# inside pod:
export BAO_ADDR=http://127.0.0.1:8200
bao login  # paste root token
```

- [ ] **Step 2: Write bootstrap policy `terraform` (minimal, tofu will replace)**

```bash
bao policy write terraform - <<'EOF'
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF
```

- [ ] **Step 3: Enable AppRole + create role**

```bash
bao auth enable approle || true
bao write auth/approle/role/terraform \
  token_policies="terraform" \
  token_ttl=1h \
  token_max_ttl=4h \
  secret_id_ttl=0
```

- [ ] **Step 4: Capture credentials into 1Password**

```bash
bao read -field=role_id auth/approle/role/terraform/role-id
bao write -f -field=secret_id auth/approle/role/terraform/secret-id
```

Store as fields `approle-role-id` and `approle-secret-id` on item `openbao` (vault `Servers`). Ensure `root-token` field exists for break-glass.

- [ ] **Step 5: Verify AppRole login**

```bash
bao write auth/approle/login \
  role_id="$ROLE_ID" \
  secret_id="$SECRET_ID"
```

Expected: `client_token` issued; `bao token lookup` with that token shows policy `terraform`.

- [ ] **Step 6: Wire local tfvars (gitignored) + Terrakube ENV**

Create local `terraform/openbao/defaults.auto.tfvars` from the example (never commit). Set Terrakube workspace vars to the same four secrets + confirm `vault_addr`.

- [ ] **Step 7: No commit required if only 1P/Terrakube changed; if bootstrap-notes already edited in this task, commit that separately in Task 7**

---

### Task 4: Policies + KV mount

**Files:**
- Create: `terraform/openbao/policies.tf`
- Create: `terraform/openbao/secrets.tf`

**Interfaces:**
- Consumes: AppRole provider login from Task 2/3
- Produces: policies `admin`, `eso-read`, `terraform`; mount `secret/` type `kv-v2`

- [ ] **Step 1: Write `policies.tf`**

```hcl
resource "vault_policy" "admin" {
  name = "admin"

  policy = <<-EOT
    path "*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
  EOT
}

resource "vault_policy" "eso_read" {
  name = "eso-read"

  policy = <<-EOT
    path "secret/data/*" {
      capabilities = ["read", "list"]
    }
    path "secret/metadata/*" {
      capabilities = ["read", "list"]
    }
  EOT
}

resource "vault_policy" "terraform" {
  name = "terraform"

  policy = <<-EOT
    path "*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
  EOT
}
```

- [ ] **Step 2: Write `secrets.tf`**

```hcl
resource "vault_mount" "secret" {
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "KV v2 application secrets (paths secret/<app>/...)"
}
```

- [ ] **Step 3: Init + plan (AppRole must work)**

```bash
cd terraform/openbao
make check
tofu plan
```

Expected: create 3 policies + 1 mount (or update-in-place if mount/policies already exist from manual bootstrap — then import in Step 4).

- [ ] **Step 4: Import if already present**

Only if plan wants to create and API already has them:

```bash
tofu import vault_policy.admin admin
tofu import vault_policy.eso_read eso-read
tofu import vault_policy.terraform terraform
tofu import vault_mount.secret secret
```

Re-plan until create/update looks correct (no destroy of unrelated auth).

- [ ] **Step 5: Apply**

```bash
tofu apply
```

Expected: policies and `secret/` present; `bao read sys/mounts` shows `secret/` version 2.

- [ ] **Step 6: Commit**

```bash
git add terraform/openbao/policies.tf terraform/openbao/secrets.tf
git commit -m "$(cat <<'EOF'
Manage OpenBao admin/eso-read/terraform policies and KV secret/.

EOF
)"
```

---

### Task 5: OIDC auth (`default_role=admin`)

**Files:**
- Create: `terraform/openbao/auth_oidc.tf`

**Interfaces:**
- Consumes: `var.oidc_client_id`, `var.oidc_client_secret`, `vault_policy.admin`
- Produces: OIDC mount with `default_role=admin`; role `admin` with Authentik redirect URI

- [ ] **Step 1: Write `auth_oidc.tf`**

```hcl
resource "vault_jwt_auth_backend" "oidc" {
  path               = "oidc"
  type               = "oidc"
  oidc_discovery_url = "https://auth.dominiksiejak.pl/application/o/openbao/"
  oidc_client_id     = var.oidc_client_id
  oidc_client_secret = var.oidc_client_secret
  default_role       = "admin"
  tune {
    listing_visibility = "unauth"
  }
}

resource "vault_jwt_auth_backend_role" "admin" {
  backend        = vault_jwt_auth_backend.oidc.path
  role_name      = "admin"
  role_type      = "oidc"
  token_policies = [vault_policy.admin.name]

  user_claim            = "sub"
  groups_claim          = "groups"
  oidc_scopes           = ["openid", "profile", "email", "groups"]
  allowed_redirect_uris = [
    "https://openbao.dominiksiejak.pl/ui/vault/auth/oidc/oidc/callback",
  ]
  bound_audiences = [var.oidc_client_id]
}
```

- [ ] **Step 2: Plan**

```bash
tofu plan
```

Expected: create OIDC backend + role (or import if runbook already enabled `oidc/`).

- [ ] **Step 3: Import if needed**

```bash
tofu import vault_jwt_auth_backend.oidc oidc
tofu import 'vault_jwt_auth_backend_role.admin' oidc/admin
```

- [ ] **Step 4: Apply**

```bash
tofu apply
```

- [ ] **Step 5: Manual UI verify**

Open `https://openbao.dominiksiejak.pl` → method `oidc/` → **leave Role empty** → Sign in → Authentik → land authenticated with policy `admin`.

Do **not** type `Default`.

- [ ] **Step 6: Commit**

```bash
git add terraform/openbao/auth_oidc.tf
git commit -m "$(cat <<'EOF'
Configure OpenBao OIDC admin role with default_role for blank UI login.

EOF
)"
```

---

### Task 6: Kubernetes auth + AppRole role in tofu

**Files:**
- Create: `terraform/openbao/auth_kubernetes.tf`
- Create: `terraform/openbao/auth_approle.tf`

**Interfaces:**
- Consumes: `vault_policy.eso_read`, `vault_policy.terraform`
- Produces: K8s role `eso-openbao` matching `ClusterSecretStore/openbao`; AppRole role `terraform` definition owned by tofu (secret_id stays out of state)

- [ ] **Step 1: Write `auth_kubernetes.tf`**

```hcl
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  backend            = vault_auth_backend.kubernetes.path
  kubernetes_host     = "https://kubernetes.default.svc:443"
  # OpenBao pod SA + chart authDelegator perform TokenReview.
  disable_local_ca_jwt = false
}

resource "vault_kubernetes_auth_backend_role" "eso_openbao" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "eso-openbao"
  bound_service_account_names      = ["eso-openbao"]
  bound_service_account_namespaces = ["external-secrets"]
  token_policies                   = [vault_policy.eso_read.name]
  token_ttl                        = 3600
}
```

- [ ] **Step 2: Write `auth_approle.tf`**

```hcl
resource "vault_auth_backend" "approle" {
  type = "approle"
  path = "approle"
}

resource "vault_approle_auth_backend_role" "terraform" {
  backend        = vault_auth_backend.approle.path
  role_name      = "terraform"
  token_policies = [vault_policy.terraform.name]
  token_ttl      = 3600
  token_max_ttl  = 14400
  secret_id_ttl  = 0
}
```

Do **not** add `vault_approle_auth_backend_role_secret_id` — regenerating it would break Terrakube/local/GHA until 1P is updated every apply.

- [ ] **Step 3: Plan + import existing mounts/roles**

```bash
tofu plan
# if already enabled from bootstrap/runbook:
tofu import vault_auth_backend.kubernetes kubernetes
tofu import vault_kubernetes_auth_backend_config.kubernetes kubernetes
tofu import vault_kubernetes_auth_backend_role.eso_openbao kubernetes/eso-openbao
tofu import vault_auth_backend.approle approle
tofu import vault_approle_auth_backend_role.terraform approle/terraform
tofu plan
tofu apply
```

Expected: no replacement of AppRole that would invalidate `secret_id`; `eso-openbao` bound to SA/ns above.

- [ ] **Step 4: Verify ClusterSecretStore**

```bash
kubectl --context k8s@lake get clustersecretstore openbao
```

Expected: `Ready` / `Valid`. If not, check OpenBao audit/logs for TokenReview failures and confirm chart `authDelegator` still enabled in `kubernetes/platform/openbao/values.yaml`.

- [ ] **Step 5: Re-verify AppRole tofu plan is clean**

```bash
tofu plan
```

Expected: `No changes`.

- [ ] **Step 6: Commit**

```bash
git add terraform/openbao/auth_kubernetes.tf terraform/openbao/auth_approle.tf
git commit -m "$(cat <<'EOF'
Manage OpenBao Kubernetes ESO role and AppRole terraform role in tofu.

EOF
)"
```

---

### Task 7: Bootstrap notes + AGENTS.md

**Files:**
- Modify: `kubernetes/platform/openbao/resources/bootstrap-notes.yaml`
- Modify: `AGENTS.md`

**Interfaces:**
- Produces: runbook that stops duplicating day-2 OIDC/K8s policy steps; points at `terraform/openbao` and AppRole chicken-egg

- [ ] **Step 1: Rewrite `RUNBOOK.md` data in bootstrap ConfigMap**

Replace day-2 sections so the ConfigMap contains essentially:

```markdown
# OpenBao bootstrap

## 1. Init (once)
kubectl exec -n openbao openbao-0 -- bao operator init -key-shares=5 -key-threshold=3
Store unseal-key-1..3 and root-token in 1Password Servers/openbao.
Force-sync: kubectl annotate externalsecret openbao-unseal -n openbao force-sync=$(date +%s) --overwrite

## 2. AppRole chicken-egg (once, root token)
# Full commands: docs/superpowers/plans/2026-10-31-openbao-tofu-auth.md Task 3
# Result: 1Password fields approle-role-id / approle-secret-id

## 3. Day-2 config
# terraform/openbao (Terrakube workspace openbao) owns:
#   KV secret/, policies, OIDC default_role=admin, kubernetes eso-openbao, approle terraform
# Local: copy defaults.auto.tfvars.example → defaults.auto.tfvars (gitignored)
# UI: method oidc/, leave Role blank (do not type Default)

## 4. Break-glass
# root-token in 1Password; prefer OIDC UI or AppRole tofu thereafter
```

Keep init/unseal force-sync exact; drop the old kubectl OIDC/K8s policy blocks as source of truth (they fight tofu).

- [ ] **Step 2: Patch `AGENTS.md` Data and secrets / Layout bullets**

Add near the OpenBao sentence:

- Day-2 OpenBao API config (policies, engines, OIDC/K8s/AppRole) lives in `terraform/openbao`; do not re-run obsolete kubectl auth blocks from memory — see `kubernetes/platform/openbao/resources/bootstrap-notes.yaml` for init/AppRole chicken-egg only.

Also fix the path mention if it still says `kubernetes/openbao` → `kubernetes/platform/openbao`.

- [ ] **Step 3: Commit**

```bash
git add kubernetes/platform/openbao/resources/bootstrap-notes.yaml AGENTS.md
git commit -m "$(cat <<'EOF'
Point OpenBao bootstrap at terraform/openbao for day-2 auth.

EOF
)"
```

---

### Task 8: End-to-end verification

**Files:** none (verification only)

- [ ] **Step 1: OIDC UI** — blank Role → Authentik admin → OpenBao UI works
- [ ] **Step 2: `cd terraform/openbao && tofu plan`** — No changes (AppRole)
- [ ] **Step 3: `kubectl get clustersecretstore openbao`** — Ready
- [ ] **Step 4: Confirm no app ExternalSecret uses `secretStoreRef.name: openbao` yet**

```bash
rg -n 'name: openbao' kubernetes --glob '**/externalsecret*.yaml'
```

Expected: only platform ExternalSecrets for unseal/oidc / ClusterSecretStore definition — no app consumer flip.

- [ ] **Step 5: Optional commit** — only if verification found doc typos to fix; otherwise done

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Blank Role → admin OIDC | 5 |
| `terraform/openbao` engines/policies/auth | 2, 4, 5, 6 |
| AppRole shared local/Terrakube/GHA shape | 3, 6 |
| K8s auth ESO `eso-openbao` | 6 |
| Authentik groups scope for OpenBao | 1 |
| Bootstrap notes + chicken-egg | 3, 7 |
| No ExternalSecret flip / no GHA workflow | 8 (verify) |
| AGENTS note | 7 |

## Placeholder scan

No TBD/TODO steps; import commands and resource HCL are explicit; AppRole secret_id deliberately omitted from state.
