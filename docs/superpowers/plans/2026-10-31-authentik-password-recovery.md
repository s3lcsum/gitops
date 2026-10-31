# Authentik Password Recovery + Passkey Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable Forgot password? via Zoho email with MFA after the recovery link, and passwordless passkey login that skips the password on the Authentik login page.

**Architecture:** Split SMTP into Secret `authentik-email` (1Password → ExternalSecret) mounted via second `envFrom` on server + worker. OpenTofu adds MFA to existing `password-recovery`, creates `authentication-passwordless`, and wires brand + login identification `recovery_flow` / `passwordless_flow` (import live objects first).

**Tech Stack:** Kubernetes ExternalSecrets, Authentik 2026.8.5, OpenTofu + goauthentik/authentik provider 2026.8.0, Zoho SMTP, 1Password.

## Global Constraints

- Do **not** replace or Own Secret `authentik` (core keys stay out-of-band).
- SMTP only in Secret `authentik-email`; Zoho host `smtp.zoho.eu`, port `587`, TLS, from `root@mail.dominiksiejak.pl`.
- Recovery MFA: `device_classes = ["webauthn", "totp", "static"]`, `not_configured_action = "deny"`.
- Passwordless: WebAuthn-only validate → login; no password stage.
- Import live brand + `default-authentication-identification` before first apply; never wipe `password_stage`.
- Spec: `docs/superpowers/specs/2026-10-31-authentik-password-recovery-design.md`.
- Apply authentik tofu via `cd tofu && make apply-module MODULE=authentik` (or `cd tofu/authentik && make apply`) — not Terrakube.

## File map

| File | Role |
|---|---|
| `kubernetes/platform/authentik/resources/externalsecret-email.yaml` | Create — ESO → Secret `authentik-email` |
| `kubernetes/platform/authentik/resources/deployment.yaml` | Modify — second `envFrom` on server + worker |
| `kubernetes/platform/authentik/kustomization.yaml` | Modify — list new ExternalSecret |
| `tofu/authentik/flows.tf` | Modify — recovery MFA + skip-if-restored; add passwordless flow |
| `tofu/authentik/brand.tf` | Create — brand + login identification wiring |
| `tofu/authentik/imports.tf` | Create — import blocks for live brand + identification (IDs filled at apply time) |

---

### Task 1: 1Password item + ExternalSecret for SMTP

**Files:**
- Create: `kubernetes/platform/authentik/resources/externalsecret-email.yaml`
- Modify: `kubernetes/platform/authentik/kustomization.yaml`
- Test: `kubectl -n authentik get externalsecret authentik-email` (after Argo sync; needs 1Password item first)

**Interfaces:**
- Consumes: ClusterSecretStore `onepassword`; 1Password item path `authentik/email` with fields `username`, `password` (Zoho mailbox + app password)
- Produces: Secret `authentik-email` with `AUTHENTIK_EMAIL__*` keys for Task 2

- [ ] **Step 1: Create 1Password item (human / agent with 1Password access)**

Create item titled `email` in vault path used by ESO as `authentik/email` (same pattern as `authentik/ldap-token`).

Fields:
- `username` = `root@mail.dominiksiejak.pl`
- `password` = Zoho app password for that mailbox

Tag: `ArgoCD External Secrets Operator` (required for ESO read).

- [ ] **Step 2: Write ExternalSecret manifest**

Create `kubernetes/platform/authentik/resources/externalsecret-email.yaml`:

```yaml
# Zoho SMTP for Authentik global email (recovery). 1Password item: authentik/email.
# Tag: ArgoCD External Secrets Operator.
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: authentik-email
  namespace: authentik
  labels:
    app.kubernetes.io/name: authentik-email
    app.kubernetes.io/instance: authentik
    app.kubernetes.io/part-of: authentik
    app.kubernetes.io/managed-by: argocd
spec:
  refreshPolicy: OnChange
  refreshInterval: 0s
  secretStoreRef:
    name: onepassword
    kind: ClusterSecretStore
  target:
    name: authentik-email
    creationPolicy: Owner
    deletionPolicy: Retain
    template:
      engineVersion: v2
      metadata:
        labels:
          app.kubernetes.io/name: authentik-email
          app.kubernetes.io/part-of: authentik
        annotations:
          argocd.argoproj.io/sync-options: Prune=false
      data:
        AUTHENTIK_EMAIL__HOST: smtp.zoho.eu
        AUTHENTIK_EMAIL__PORT: "587"
        AUTHENTIK_EMAIL__USERNAME: "{{ .username }}"
        AUTHENTIK_EMAIL__PASSWORD: "{{ .password }}"
        AUTHENTIK_EMAIL__USE_TLS: "true"
        AUTHENTIK_EMAIL__FROM: root@mail.dominiksiejak.pl
  data:
    - secretKey: username
      remoteRef:
        key: authentik/email
        property: username
    - secretKey: password
      remoteRef:
        key: authentik/email
        property: password
```

- [ ] **Step 3: Register in kustomization**

In `kubernetes/platform/authentik/kustomization.yaml`, add under `resources:`:

```yaml
  - resources/externalsecret-email.yaml
```

Keep existing entries; order after `deployment.yaml` is fine.

- [ ] **Step 4: Commit**

```bash
git add kubernetes/platform/authentik/resources/externalsecret-email.yaml \
  kubernetes/platform/authentik/kustomization.yaml
git commit -m "feat(authentik): ESO secret for Zoho SMTP email"
```

- [ ] **Step 5: Verify Secret after Argo sync**

Run:

```bash
kubectl -n authentik get externalsecret authentik-email
kubectl -n authentik get secret authentik-email -o jsonpath='{.data}' | jq 'keys'
```

Expected: ExternalSecret `SecretSynced=True`. Secret keys include `AUTHENTIK_EMAIL__HOST`, `AUTHENTIK_EMAIL__PORT`, `AUTHENTIK_EMAIL__USERNAME`, `AUTHENTIK_EMAIL__PASSWORD`, `AUTHENTIK_EMAIL__USE_TLS`, `AUTHENTIK_EMAIL__FROM`.

Do **not** print secret values.

---

### Task 2: Mount `authentik-email` on server + worker

**Files:**
- Modify: `kubernetes/platform/authentik/resources/deployment.yaml` (server `envFrom` ~L39–41; worker `envFrom` ~L136–138)
- Test: `kubectl -n authentik exec deploy/authentik-server -- env | rg AUTHENTIK_EMAIL`

**Interfaces:**
- Consumes: Secret `authentik-email` from Task 1
- Produces: Runtime global email settings for Authentik email stages (`use_global_settings = true`)

- [ ] **Step 1: Patch server envFrom**

In Deployment `authentik-server`, change:

```yaml
          envFrom:
            - secretRef:
                name: authentik
```

to:

```yaml
          envFrom:
            - secretRef:
                name: authentik
            - secretRef:
                name: authentik-email
```

- [ ] **Step 2: Patch worker envFrom**

Same change on Deployment `authentik-worker` container `worker` `envFrom`.

- [ ] **Step 3: Commit**

```bash
git add kubernetes/platform/authentik/resources/deployment.yaml
git commit -m "feat(authentik): mount SMTP secret on server and worker"
```

- [ ] **Step 4: Verify env after rollout**

Run:

```bash
kubectl -n authentik rollout status deploy/authentik-server
kubectl -n authentik rollout status deploy/authentik-worker
kubectl -n authentik exec deploy/authentik-server -- env | rg '^AUTHENTIK_EMAIL__'
kubectl -n authentik exec deploy/authentik-worker -- env | rg '^AUTHENTIK_EMAIL__'
```

Expected: both show `HOST=smtp.zoho.eu`, `PORT=587`, `USE_TLS=true`, `FROM=root@mail.dominiksiejak.pl`, plus USERNAME (password present but do not print).

Optional smoke (from worker): Authentik Admin → System → Email → send test, or `ak test_email` if shell available in image.

---

### Task 3: Recovery MFA + skip-if-restored in tofu

**Files:**
- Modify: `tofu/authentik/flows.tf` (recovery flow block through `authentik_flow_stage_binding.recovery`)
- Test: `make -C tofu/authentik check` (or `cd tofu && make check-module MODULE=authentik` if that target exists — prefer module Makefile)

**Interfaces:**
- Consumes: existing `authentik_flow.recovery`, email/password stages
- Produces: MFA stage + binding order 25; skip-if-restored policy on identification binding; flow `authentication = require_unauthenticated`

- [ ] **Step 1: Set recovery flow authentication mode**

On `authentik_flow.recovery`, add:

```hcl
  authentication     = "require_unauthenticated"
```

Keep existing name/title/slug/designation/policy_engine_mode.

- [ ] **Step 2: Add skip-if-restored policy + MFA stage**

After `authentik_stage_email.recovery_email`, insert:

```hcl
resource "authentik_policy_expression" "recovery_skip_if_restored" {
  name       = "recovery-skip-if-restored"
  expression = <<-EOF
    return bool(request.context.get("is_restored", True))
  EOF
}

resource "authentik_stage_authenticator_validate" "recovery_mfa" {
  name                  = "recovery-mfa"
  device_classes        = ["webauthn", "totp", "static"]
  not_configured_action = "deny"
}
```

- [ ] **Step 3: Extend recovery stage bindings**

Replace `authentik_flow_stage_binding.recovery` for_each map with:

```hcl
resource "authentik_flow_stage_binding" "recovery" {
  for_each = {
    identification = { stage = authentik_stage_identification.recovery_identification.id, order = 10 }
    email          = { stage = authentik_stage_email.recovery_email.id, order = 20 }
    mfa            = { stage = authentik_stage_authenticator_validate.recovery_mfa.id, order = 25 }
    password       = { stage = authentik_stage_prompt.recovery_password_prompt.id, order = 30 }
    user_write     = { stage = authentik_stage_user_write.recovery_user_write.id, order = 40 }
    login          = { stage = authentik_stage_user_login.recovery_login.id, order = 50 }
  }

  target = authentik_flow.recovery.uuid
  stage  = each.value.stage
  order  = each.value.order
}

resource "authentik_policy_binding" "recovery_skip_identification_if_restored" {
  target  = authentik_flow_stage_binding.recovery["identification"].id
  policy  = authentik_policy_expression.recovery_skip_if_restored.id
  order   = 0
  enabled = true
}
```

Note: Official MFA blueprint keeps skip-if-restored on identification only (email binding policy absent). Do not bind this policy to the email stage.

- [ ] **Step 4: OpenTofu check**

Run: `make -C tofu/authentik check`

Expected: fmt + validate pass.

- [ ] **Step 5: Commit**

```bash
git add tofu/authentik/flows.tf
git commit -m "feat(authentik): MFA on password-recovery flow"
```

Do **not** apply yet — wait for Tasks 4–5 so one plan/apply lands brand + passwordless together (or apply this alone if preferred; login link still missing until Task 5).

---

### Task 4: Passwordless passkey flow in tofu

**Files:**
- Modify: `tofu/authentik/flows.tf` (new section after recovery bindings)
- Test: `make -C tofu/authentik check`

**Interfaces:**
- Consumes: none from Task 3 beyond shared module
- Produces: `authentik_flow.passwordless.uuid` for Task 5 `passwordless_flow`

- [ ] **Step 1: Add passwordless flow + stages**

Append to `tofu/authentik/flows.tf`:

```hcl
#───────────────────────────────────────────────────────────────────────────────
# Passwordless (passkey) authentication
#───────────────────────────────────────────────────────────────────────────────

resource "authentik_flow" "passwordless" {
  name               = "authentication-passwordless"
  title              = "Sign in with a passkey"
  slug               = "authentication-passwordless"
  designation        = "authentication"
  authentication     = "require_unauthenticated"
  policy_engine_mode = "any"
}

resource "authentik_stage_authenticator_validate" "passwordless_webauthn" {
  name                       = "passwordless-webauthn"
  device_classes             = ["webauthn"]
  not_configured_action      = "deny"
  webauthn_user_verification = "required"
}

resource "authentik_stage_user_login" "passwordless_login" {
  name = "passwordless-login"
}

resource "authentik_flow_stage_binding" "passwordless" {
  for_each = {
    webauthn = { stage = authentik_stage_authenticator_validate.passwordless_webauthn.id, order = 10 }
    login    = { stage = authentik_stage_user_login.passwordless_login.id, order = 100 }
  }

  target = authentik_flow.passwordless.uuid
  stage  = each.value.stage
  order  = each.value.order
}
```

- [ ] **Step 2: OpenTofu check**

Run: `make -C tofu/authentik check`

Expected: pass.

- [ ] **Step 3: Commit**

```bash
git add tofu/authentik/flows.tf
git commit -m "feat(authentik): passwordless WebAuthn login flow"
```

---

### Task 5: Brand + login identification wiring (import live)

**Files:**
- Create: `tofu/authentik/brand.tf`
- Create: `tofu/authentik/imports.tf`
- Test: `cd tofu/authentik && tofu plan` — must show update-in-place for brand/identify, not destroy of password stage

**Interfaces:**
- Consumes: `authentik_flow.recovery.uuid`, `authentik_flow.passwordless.uuid`
- Produces: Forgot password? link + Use a passkey entry on login page

- [ ] **Step 1: Look up live brand + identification IDs**

With Authentik API token available (same as tofu `local.secret.authentik_token`):

```bash
# Brand (default)
curl -sS -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
  'https://auth.dominiksiejak.pl/api/v3/core/brands/?default=true' | jq '.results[0] | {pk, domain, branding_title, flow_recovery, flow_authentication}'

# Login identification stage
curl -sS -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
  'https://auth.dominiksiejak.pl/api/v3/stages/identification/?name=default-authentication-identification' \
  | jq '.results[0] | {pk, name, user_fields, password_stage, recovery_flow, passwordless_flow, sources}'
```

Record:
- Brand `pk` and `domain`
- Identification stage `pk`
- Live `password_stage` UUID and `user_fields` / `sources` (must preserve)

- [ ] **Step 2: Write import blocks**

Create `tofu/authentik/imports.tf` with IDs from Step 1 (replace placeholders):

```hcl
import {
  to = authentik_brand.default
  id = "BRAND_PK"
}

import {
  to = authentik_stage_identification.default_authentication
  id = "IDENTIFICATION_PK"
}
```

- [ ] **Step 3: Write brand + identification resources**

Create `tofu/authentik/brand.tf`. Fill branding fields from the API response so apply does not blank logo/title. Minimal shape:

```hcl
resource "authentik_brand" "default" {
  domain         = "BRAND_DOMAIN" # from API, often "authentik-default"
  default        = true
  branding_title = "BRANDING_TITLE" # from API
  # Include branding_logo / branding_favicon from API if set; omit only if API null.

  flow_recovery = authentik_flow.recovery.uuid
  # If API shows flow_authentication / flow_invalidation / flow_user_settings set,
  # copy those UUIDs here so plan does not clear them.
}

resource "authentik_stage_identification" "default_authentication" {
  name = "default-authentication-identification"

  user_fields = ["USERNAME_OR_FROM_API"] # exact list from API

  password_stage    = "PASSWORD_STAGE_PK_FROM_API"
  recovery_flow     = authentik_flow.recovery.uuid
  passwordless_flow = authentik_flow.passwordless.uuid

  # If API returns sources, set sources = [...] with those UUIDs.
  # Preserve pretend_user_exists / show_matched_user / enable_remember_me from API.
}
```

Do **not** invent a new password stage. If `password_stage` is empty in API, stop and investigate — login is passwordless-only already or misnamed stage.

- [ ] **Step 4: Plan and inspect**

Run: `cd tofu/authentik && tofu plan`

Expected:
- Import of brand + identification
- Create passwordless resources (if Task 4 not applied yet) and recovery MFA (if Task 3 not applied)
- Update brand: set `flow_recovery` only (plus any drift you intentionally matched)
- Update identification: set `recovery_flow` + `passwordless_flow`; **no** replacement of `password_stage`

If plan wants to destroy/recreate identification or clear `password_stage` → fix resource attrs to match live; do not apply.

- [ ] **Step 5: Apply**

Run: `cd tofu && make apply-module MODULE=authentik`

Expected: apply succeeds.

- [ ] **Step 6: Commit**

```bash
git add tofu/authentik/brand.tf tofu/authentik/imports.tf tofu/authentik/flows.tf
git commit -m "feat(authentik): wire recovery and passwordless on login"
```

After successful import+apply, `imports.tf` may stay (OpenTofu keeps import blocks as no-ops) or be removed in a follow-up chore commit — either is fine; do not leave wrong placeholder IDs.

---

### Task 6: End-to-end verification

**Files:**
- None (manual / browser)

**Interfaces:**
- Consumes: Tasks 1–5 live

- [ ] **Step 1: Forgot password path**

1. Incognito → `https://auth.dominiksiejak.pl`
2. Confirm **Forgot password?** visible
3. Enter a user email that has MFA enrolled (passkey and/or TOTP)
4. Confirm Zoho mail arrives (from `root@mail.dominiksiejak.pl`)
5. Open link → MFA challenge → set new password → land logged in
6. Log out; log in with new password

- [ ] **Step 2: Passwordless path**

1. Incognito login page → **Use a passkey** (or equivalent)
2. Complete WebAuthn → session without password prompt

- [ ] **Step 3: Negative MFA**

1. User with **no** authenticator enrolled → Forgot password → after email link, MFA stage denies
2. Expected: cannot set password without admin help

- [ ] **Step 4: Confirm core secret untouched**

Run:

```bash
kubectl -n authentik get secret authentik -o jsonpath='{.data}' | jq 'keys'
kubectl -n authentik get secret authentik-email -o jsonpath='{.data}' | jq 'keys'
```

Expected: `authentik` keys unchanged vs pre-change; SMTP keys only on `authentik-email`.

---

## Spec coverage (self-review)

| Spec requirement | Task |
|---|---|
| Zoho SMTP via split ESO secret | 1–2 |
| Recovery MFA webauthn/totp/static deny | 3 |
| Passwordless WebAuthn login | 4–5 |
| Brand + identify recovery/passwordless wiring | 5 |
| Core Secret `authentik` untouched | 1–2, 6 |
| E2E + no-MFA deny | 6 |
| Passkey enrollment out of scope | noted in Global Constraints / Task 6 prereq |

No TBD placeholders. Import IDs are runtime-filled in Task 5 Step 1–2 by design (cannot hardcode without live API).
