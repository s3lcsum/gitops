# Authentik Password Recovery + Passkey Login — Design

**Date:** 2026-10-31
**Status:** Approved (awaiting implementation plan)

## Goal

Enable **Forgot password?** via email (Zoho SMTP) with MFA after the recovery link, and wire **passwordless passkey login** so passkey users skip the password on the login page.

## Context (verified facts)

- `tofu/authentik/flows.tf` already defines recovery flow slug `password-recovery`: identify (email) → email stage (`use_global_settings = true`) → password prompt → user write → login.
- No `AUTHENTIK_EMAIL__*` in repo. Server/worker load Secret `authentik` via `envFrom` only (`kubernetes/platform/authentik/resources/deployment.yaml`). That secret is out-of-band (not an ExternalSecret).
- No `authentik_brand` and no tofu management of `default-authentication-identification`. Brand recovery pointer and identify `recovery_flow` / `passwordless_flow` are unset in git → Forgot password link and passkey button do not appear from IaC.
- Zoho already used for Grafana: `smtp.zoho.eu:587`, from `root@mail.dominiksiejak.pl`.
- Outpost secrets use 1Password → ExternalSecret (`authentik/ldap-token`, etc.) with tag `ArgoCD External Secrets Operator`.

## Decision

**Approach:** Split SMTP into Secret `authentik-email` (ESO from 1Password) + tofu brand/identify wiring + MFA on recovery + new passwordless flow.

Rejected:

- Merge SMTP into Secret `authentik` via ESO — risk wiping `AUTHENTIK_SECRET_KEY` / DB keys if ownership flips.
- UI-only brand + kubectl secret patch — drifts from gitops.
- Recovery without MFA — weaker than email + device proof.
- Skip password stage after passkey in recovery — that is login, not password reset.

## Architecture

```
Login (default-authentication-identification)
  ├─ password path → existing auth stages
  ├─ “Use a passkey” → authentication-passwordless
  │       WebAuthn validate → login
  └─ “Forgot password?” → password-recovery
          identify → email (Zoho) → MFA (webauthn|totp|static)
          → new password → write → login
```

SMTP: 1Password `authentik/email` → ExternalSecret → Secret `authentik-email` → second `envFrom` on authentik-server and authentik-worker. Core Secret `authentik` unchanged.

## Components

### 1. Kubernetes — SMTP

- New ExternalSecret + Secret `authentik-email` in namespace `authentik`.
- Keys (global email settings Authentik reads from env):
  - `AUTHENTIK_EMAIL__HOST=smtp.zoho.eu`
  - `AUTHENTIK_EMAIL__PORT=587`
  - `AUTHENTIK_EMAIL__USERNAME` / `AUTHENTIK_EMAIL__PASSWORD` from 1Password
  - `AUTHENTIK_EMAIL__USE_TLS=true`
  - `AUTHENTIK_EMAIL__FROM=root@mail.dominiksiejak.pl`
- Patch server + worker Deployments: add `envFrom` secretRef `authentik-email`.
- Manual once: create 1Password item `authentik/email` (Zoho app password), tag for ESO.

### 2. OpenTofu — recovery MFA

- Add `authentik_stage_authenticator_validate` on `password-recovery` after email (order ~25).
- `device_classes = ["webauthn", "totp", "static"]`
- `not_configured_action = "deny"` (no enrolled MFA → no self-service reset; admin only).
- Keep existing email template, 30m token, `activate_user_on_success = true`.

### 3. OpenTofu — passwordless passkey

- New flow slug `authentication-passwordless`, designation `authentication`.
- Stages: WebAuthn-only authenticator validate (`device_classes = ["webauthn"]`, `not_configured_action = "deny"`, user verification required) → user login.
- Set `passwordless_flow` on the login identification stage.

### 4. OpenTofu — Forgot password link

- Manage default brand (`flow_recovery` → `password-recovery` UUID); import existing brand if required.
- Import/manage `default-authentication-identification`: set `recovery_flow` + `passwordless_flow`; preserve existing `password_stage` and other live attrs (plan carefully — no wipe of password stage).

## Out of scope

- Passkey enrollment UX (users enroll via Authentik user settings / existing WebAuthn setup; prefer discoverable/resident key for passwordless).
- Migrating core Secret `authentik` to ExternalSecret / OpenBao.
- Changing recovery identify fields beyond current email-based stage.
- Blocking inactive users before email (disclosure tradeoff); keep current activate-on-success behavior.

## Apply path

1. Create 1Password item; commit k8s ExternalSecret + deployment `envFrom`; Argo sync; confirm env on server + worker.
2. Tofu plan/apply `authentik` module (MFA binding, passwordless flow, brand + identify wiring; import brand/identify if first apply).
3. Manual E2E tests below.

## Success criteria

- Incognito `https://auth.dominiksiejak.pl`: **Forgot password?** visible; email arrives from Zoho; after link, MFA required; new password works.
- Login shows passkey / passwordless entry; completing WebAuthn skips password and creates a session.
- User with no MFA cannot complete recovery (denied at MFA stage).
- Secret `authentik` keys unchanged; only `authentik-email` holds SMTP.

## Risks

- Importing `default-authentication-identification` without matching live attrs can break login — capture live state before apply; use import + narrowly scoped attrs.
- Users without MFA lose self-service reset by design.
- Lost passkey + forgotten password + no TOTP/static → admin reset only.
