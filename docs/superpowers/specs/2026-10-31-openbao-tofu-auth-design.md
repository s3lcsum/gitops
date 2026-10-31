# OpenBao OpenTofu Auth & Policies — Design

Date: 2026-10-31
Cluster: `k8s@lake` (`192.168.89.252`)
Extends: `docs/superpowers/specs/2026-10-10-openbao-secrets-design.md` (Phase 1 platform)

## Goal

Make OpenBao day-2 operable as code:

1. UI login at `https://openbao.dominiksiejak.pl` via Authentik OIDC with **empty Role** → policy `admin`.
2. OpenTofu module owns engines, policies, and auth roles.
3. Dual machine auth: **Kubernetes** for ESO; **AppRole** for tofu (local, GitHub Actions, and Terrakube share the same `role_id` / `secret_id`).

No 1Password → KV migration and no ExternalSecret store flip in this cut.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Human UI auth | OIDC → Authentik; `default_role=admin`; Role field left blank |
| Admin gate | Authentik app binding already admins-only; OIDC role hard-binds policy `admin` |
| Groups claim | Add Authentik `groups` scope on OpenBao provider (future); v1 does **not** map groups → policies |
| Policy/engine IaC | New `terraform/openbao` Terrakube workspace; HashiCorp `vault` provider against OpenBao API |
| Provider address | `https://openbao.dominiksiejak.pl` (same for local, GHA, Terrakube) |
| ESO auth | Kubernetes auth role `eso-openbao` → policy `eso-read` |
| Tofu / CI auth | AppRole role `terraform` → policy `terraform`; credentials in 1Password item `openbao` |
| Shared CI secrets | One AppRole pair for local `tofu`, GHA, and Terrakube workspace ENV |
| KV layout | Mount `secret/` (KV v2); paths `secret/<app>/…` so later per-app ESO roles need no remount |
| Chicken-egg | One-shot root bootstrap creates AppRole + stores ids in 1P; thereafter AppRole only; root = break-glass |
| Rejected | Managing Bao API state via Kustomize alone; resurrecting `terraform/vault`; bank-vaults operator; per-app ESO roles in this cut |

## Current state

- OpenBao Phase 1 live: Raft 1×, Shamir unseal CronJob, IngressRoute, `ClusterSecretStore/openbao` → role `eso-openbao`.
- Bootstrap still a ConfigMap runbook (`kubernetes/platform/openbao/resources/bootstrap-notes.yaml`); OIDC/K8s auth may be incomplete (UI "Invalid role" if role/`default_role` missing or Role typed as `Default`).
- Authentik `oauth2_applications.openbao` exists; admins-only via `authentik_policy_binding.admin_access`; not in `user_accessible_apps`.
- ExternalSecrets still use `ClusterSecretStore/onepassword`.

## Architecture

```
Authentik ──OIDC──► OpenBao UI/API
                      │
     ┌────────────────┼────────────────┐
     ▼                ▼                ▼
  oidc/admin     kubernetes/      approle/terraform
  (humans)       eso-openbao      (local + GHA + Terrakube)
                      │                │
                      ▼                ▼
                 policy eso-read   policy terraform
                      │                │
                      └────────┬───────┘
                               ▼
                        KV v2 secret/
```

### Auth methods

| Mount | Role | Bound to | Policies |
|-------|------|----------|----------|
| `oidc/` | `admin` (`default_role`) | Authentik users who pass app access | `admin` |
| `kubernetes/` | `eso-openbao` | SA `eso-openbao` in `external-secrets` | `eso-read` |
| `approle/` | `terraform` | Anyone with role_id + secret_id | `terraform` |

### Policies (intent)

- **`admin`**: broad UI/operator capability (`*` with create/read/update/delete/list/sudo) for human break-glass day-to-day via OIDC.
- **`eso-read`**: read/list `secret/data/*` and `secret/metadata/*` only.
- **`terraform`**: manage mounts, policies, auth backends/roles, and KV as needed for this module to converge (sudo on `sys/*` / auth paths as required by the vault provider). Narrow later if desired; start capable enough that the module is self-managing after bootstrap.

### Secrets in 1Password (`Servers` / `openbao`)

| Field | Purpose |
|-------|---------|
| `unseal-key-1..3` | Existing Shamir shares (unchanged) |
| `oidc-client-id` / `oidc-client-secret` | Existing Authentik client (unchanged) |
| `root-token` | Break-glass; bootstrap only |
| `approle-role-id` / `approle-secret-id` | Shared tofu credentials (local / GHA / Terrakube) |

Terrakube workspace `openbao` ENV (and local/`defaults.auto.tfvars` pattern): `VAULT_ADDR`, AppRole id+secret (provider-specific var names as implemented). Never commit tfvars.

## Components

### `terraform/openbao/` (new)

Same module shape as siblings (`providers.tf` remote backend Terrakube org `HomeLab` workspace `openbao`, `Makefile` → `base.Makefile`, pinned providers exact versions).

Owns (non-exhaustive resource list):

- `vault_mount.secret` (KV v2)
- `vault_policy.admin` / `eso-read` / `terraform`
- `vault_auth_backend` + config for `oidc`, `kubernetes`, `approle` (import or adopt if already enabled manually)
- `vault_jwt_auth_backend_role.admin` (OIDC role; `default_role` on backend config)
- `vault_kubernetes_auth_backend_role.eso_openbao`
- `vault_approle_auth_backend_role.terraform` (+ secret_id lifecycle as designed; rotate via 1P when needed)

OIDC discovery URL: `https://auth.dominiksiejak.pl/application/o/openbao/`.
Allowed redirect: `https://openbao.dominiksiejak.pl/ui/vault/auth/oidc/oidc/callback`.
Client id/secret: from Terrakube vars / 1P (same values as Secret `openbao-oidc`).

### `terraform/authentik/` (small)

- Add OpenBao `groups` scope property mapping (same expression pattern as Argo CD / Calibre) and attach to the OpenBao OAuth provider so `groups_claim` can work later without another Authentik change.
- No change to access bindings (admins-only stays).

### `kubernetes/platform/openbao/`

- Update bootstrap ConfigMap: document AppRole chicken-egg + point day-2 config at `terraform/openbao`; keep init/unseal notes.
- No change required to `ClusterSecretStore/openbao` or `eso-openbao` SA if role name/policy stay as today.
- Optional: ExternalSecret keys for AppRole ids only if a cluster consumer needs them (not required for Terrakube/local/GHA).

### Bootstrap sequence (once)

1. OpenBao initialized + unsealed (already).
2. With root token: enable `approle` if needed; write policy `terraform` and role `terraform`; record `role_id` + `secret_id` into 1Password.
3. Configure Terrakube workspace `openbao` + local env with AppRole.
4. `tofu apply` in `terraform/openbao` converges OIDC (including `default_role=admin`), Kubernetes auth + `eso-openbao`, KV mount, remaining policies.
5. Verify UI: Role blank → Authentik → logged in as admin. Verify ESO store Ready. Verify `tofu plan` clean with AppRole.

If OIDC/K8s already exist from the old runbook, import into state rather than recreate.

## Data flows

### UI login

Browser → Traefik → OpenBao UI → method `oidc/` → blank role → `admin` → Authentik → callback → token with policy `admin`.

### Tofu apply (local / GHA / Terrakube)

AppRole login → policy `terraform` → vault provider CRUD on mounts/policies/auth.

### ESO (unchanged consumers)

`ClusterSecretStore/openbao` → K8s SA JWT → role `eso-openbao` → read KV. Zero app ExternalSecrets flipped in this cut.

## Failure modes

| Failure | Effect | Mitigation |
|---------|--------|------------|
| AppRole secret lost/rotated wrong | Tofu cannot apply | Root break-glass; rewrite secret_id; update 1P + Terrakube/GHA |
| OIDC misconfig | UI login fails | Root/AppRole still works; fix via tofu |
| Authentik down | UI OIDC fails | AppRole + K8s auth independent |
| Terrakube cannot reach hostname | Remote apply fails | Confirm DNS/WAN path to `openbao.dominiksiejak.pl`; do not switch provider to ClusterIP for local/GHA |

## Success criteria

- Blank Role on OpenBao UI OIDC login succeeds for Authentik admin; typed `Default` is not required.
- `terraform/openbao` applies via AppRole from local (and is wired for Terrakube ENV; GHA can reuse the same secrets when a workflow is added later).
- Policies `admin`, `eso-read`, `terraform` and KV `secret/` exist and match code.
- `ClusterSecretStore/openbao` remains Ready with role `eso-openbao`.
- No app ExternalSecret moved off `onepassword`.
- Root token unused for routine apply after bootstrap.

## Non-goals

- Migrating secrets from 1Password into OpenBao KV
- Flipping any app `secretStoreRef` to `openbao`
- Per-app ESO Kubernetes roles
- Recreating retired `terraform/vault` / GCS Vault state
- Shipping a new GitHub Actions tofu workflow in this cut (credentials shape must support it; workflow optional follow-up)
- Auto-unseal / HA topology changes

## Follow-up (later)

1. Map Authentik `admins` group → OpenBao identity groups / policies (use `groups` claim).
2. Per-app ESO roles bound to path prefixes under `secret/<app>/`.
3. Copy selected 1P items into KV; flip ExternalSecrets one-by-one.
4. Optional GHA workflow using the shared AppRole secrets.
5. Tighten `terraform` policy once module surface is stable.

## Repo touch list

- `docs/superpowers/specs/2026-10-31-openbao-tofu-auth-design.md` (this file)
- `terraform/openbao/` (new module)
- `terraform/authentik/applications.tf` (OpenBao groups scope mapping)
- `kubernetes/platform/openbao/resources/bootstrap-notes.yaml` (point at tofu; AppRole bootstrap)
- Terrakube UI: create workspace `openbao` + ENV vars (not in git)
- 1Password item `openbao`: AppRole fields (not in git)
- `AGENTS.md` note when implementation lands (optional in same PR)
