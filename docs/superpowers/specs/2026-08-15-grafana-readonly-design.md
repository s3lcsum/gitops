# Grafana Read-Only Design

## Goal

Make Grafana **read-only for all human users** so that every change arrives exclusively
via CasC — `stacks/monitoring` (compose env + provisioning files) and
`terraform/` (module config). No one should be able to change dashboards, alerts,
datasources, or other config through the Grafana UI.

This honors the existing rule: **prefer `stacks/` (compose + CasC provisioning) over
Terraform**; Terraform is used only for what CasC cannot manage.

## Current State (verified 2026-08-15)

- **Users**: exactly 2, both `Admin`, both in org 1:
  - `admin@localhost` — local account, from `stack/monitoring/grafana.env`
    (`GF_SECURITY_ADMIN_USER`). This is the **provisioning identity** used by
    terraform/grafana provider (basic auth) and by our deploy verification.
  - `dreewniak@gmail.com` (login `dreewniak@gmail.com`, name "Dominik Siejak") — OIDC
    user via Authentik, `authLabels: ["Generic OAuth"]`, role synced from the `role`
    claim (`ROLE_ATTRIBUTE_PATH=role`).
- **OIDC config** (compose env + `GF_AUTH_GENERIC_OAUTH_*`): enabled, name "Authentik",
  `ALLOW_SIGN_UP=true`, PKCE, role path `role`. Untouched.
- **Authentik source of the `role` claim** (`terraform/authentik/locals.tf`, grafana
  app block, mapping): `admins` group → `Admin`, `users` group → `Editor`, else
  `Viewer`. This is the single place that currently grants Admin/Editor to humans.
- **CasC hard-locks already in place** (from monitoring CasC design): dashboards
  `allowUiUpdates: false`, alerting provisioned with file provenance (UI-immutable),
  datasources provisioned. Therefore the *only* remaining way a human could edit
  anything is a **role above Viewer**.

## Scope Decisions (approved during brainstorming)

- **All humans are read-only.** This includes the OIDC user `dreewniak@gmail.com`
  (currently Admin) — no exceptions.
- The local `admin` account **stays Admin** but is strictly a **provisioning/automation
  identity** — never used to log into the UI. It remains backend-only (terraform
  provider + deploy verification), exactly as today.
- **Enforce in Authentik mapping** (single source of truth in `terraform/`), not in
  Grafana env/settings. Rationale: role claims already flow from Authentik; changing
  the mapping is declarative, self-healing (every login re-applies Viewer), and keeps
  Grafana OIDC config untouched.
- No new groups, no Teams/org-sync, no `GF_USERS_*` changes. Single-org stays.

## Design

### 1. Authentik grafana scope mapping → always `Viewer`

In `terraform/authentik/locals.tf`, replace the grafana `mapping` block. Instead of
branching on groups, emit the role claim statically:

```hcl
grafana = {
  name          = "Grafana"
  launch_url    = "https://grafana.dominiksiejak.pl"
  icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/grafana.svg"
  redirect_uris = ["https://grafana.dominiksiejak.pl/login/generic_oauth"]
  mapping       = <<-EOF
    return {"role": "Viewer"}
  EOF
}
```

Effect: on every OIDC login, Grafana's `ROLE_ATTRIBUTE_PATH=role` sync sets the user's
org role to Viewer. Existing Admin OIDC user is demoted on next login; any future
sign-up lands on Viewer automatically. Self-healing if a stray change occurs.

Result invariant: **no human can hold Editor/Admin via OIDC.** The Grafana UI is
render-only for everyone who logs in.

### 2. Where enforcement lives (summary)

| Capability | Mechanism | Enforced by |
|---|---|---|
| Dashboards/folders UI edit | `allowUiUpdates: false` | `stacks/` provisioning (already) |
| Alert rules / contact points / policy edit | file provenance | `stacks/` provisioning (already) |
| Datasource edit | provisioning | `stacks/` provisioning (already) |
| **Human org role** | **OIDC `role` claim** | **`terraform/authentik` mapping (this change)** |
| Admin access | local `admin` account only | `stacks/` env (already) |

### 3. Files changed

- `terraform/authentik/locals.tf` — grafana app `mapping` → static `{role: 'Viewer'}`.
- Apply via `tofu plan`/`tofu apply` (TFC workspace `gitops-authentik`).
- No `stacks/` changes, no Grafana restart, no compose redeploy required
  (Authentik scope mapping is server-side).

### 4. Verification

1. `tofu plan` in `terraform/authentik` → the grafana provider mapping shows the diff.
2. `tofu apply`.
3. Confirm `dreewniak@gmail.com` logs in and is `Viewer` in
   `GET /api/org/users` (needs a fresh OIDC login — role sync happens at login).
4. Spot-check UI: no Dashboard/Alerting/Datasource save/edit affordances for the
   OIDC user.
5. Confirm local `admin` still `Admin` in `/api/org/users` (automation identity).

### 5. Risks / notes

- **Existing session**: the demotion only applies on the next OIDC login while the
  user is already Admin in a live session. In practice a fresh login is required —
  acceptable; the user is the only human.
- **`role` claim is also read by any other consumer** — only grafana app in this
  repo uses this mapping; no blast radius beyond Grafana.
- **Lost convenience**: editing dashboards in UI is intentionally gone. Changes are
  made by editing CasC files and redeploying (`make apply` for stacks, `tofu` for
  terraform). This is the intended trade-off.
- If a future need to grant an admin arises, the mapping can re-introduce a group
  branch (revive the admins→Admin case) — single-line, fully CasC.

## Out of Scope

- Disabling the local `admin` account or UI login (breaks provisioning/verification).
- Team/org multi-org sync, Grafana-side `GF_USERS_*` tuning.
- Changes to the Grafana compose env or provisioning files.
