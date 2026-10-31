# Seerr Authentik OIDC Prep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align Authentik OAuth2 app `seerr` redirect URIs and launch URL with the official Seerr integration, without changing the Seerr image or enabling OIDC in Seerr yet.

**Architecture:** Single locals map edit in `terraform/authentik/locals.tf`. Existing `for_each` resources in `applications.tf` pick up the new redirect list and launch URL. No Kubernetes or Seerr config changes.

**Tech Stack:** OpenTofu, Authentik provider, Terrakube workspace for `terraform/authentik`.

## Global Constraints

- Keep Seerr image on official stable (`ghcr.io/seerr-team/seerr:v3.4.1` or current gitops pin) — never `preview-new-oidc`.
- Do not edit Seerr PVC `settings.json` or mediabox IngressRoute.
- Preserve slug `seerr` and `user_accessible_apps` membership.
- Redirect URIs must be Strict Authorization equivalents of:
  - `https://seerr.dominiksiejak.pl/login`
  - `https://seerr.dominiksiejak.pl/profile/settings/linked-accounts`
- Spec: `docs/superpowers/specs/2026-10-31-seerr-authentik-oidc-prep-design.md`

## File map

| File | Role |
|---|---|
| `terraform/authentik/locals.tf` | Only file to modify — `oauth2_applications.seerr` |
| `terraform/authentik/applications.tf` | Unchanged — already maps `redirect_uris` → strict authorization |

---

### Task 1: Update `seerr` OAuth2 locals

**Files:**
- Modify: `terraform/authentik/locals.tf` (block `oauth2_applications.seerr`)
- Test: `make -C terraform/authentik check` (fmt + validate via base Makefile)

**Interfaces:**
- Consumes: existing `oauth2_applications` map shape (`name`, `launch_url`, `icon_url`, `redirect_uris`)
- Produces: updated `seerr` entry consumed by `authentik_provider_oauth2.oauth2["seerr"]` and `authentik_application.oauth2["seerr"]`

- [x] **Step 1: Replace the `seerr` block**

Change the block in `terraform/authentik/locals.tf` to:

```hcl
    seerr = {
      name       = "Seerr"
      launch_url = "https://seerr.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/jellyseerr.svg"
      redirect_uris = [
        "https://seerr.dominiksiejak.pl/login",
        "https://seerr.dominiksiejak.pl/profile/settings/linked-accounts",
      ]
    }
```

- [x] **Step 2: Verify no preview image drift**

Run: `rg -n 'preview-new-oidc|seerr:' kubernetes/workloads/mediabox/resources/apps.yaml terraform/authentik/locals.tf`

Expected: apps.yaml still shows `ghcr.io/seerr-team/seerr:v3.4.1` (or current official pin); no `preview-new-oidc`.

- [ ] **Step 3: OpenTofu check**

Run: `make -C terraform/authentik check`

Expected: fmt + validate pass (needs Authentik API credentials / remote backend as usual for this module).

- [x] **Step 4: Commit**

```bash
git add terraform/authentik/locals.tf
git commit -m "fix(authentik): align Seerr OAuth2 redirects with official OIDC URIs."
```

- [ ] **Step 5: Apply reminder (human / Terrakube)**

Do not apply from this agent unless asked. After merge: Terrakube UI apply on HomeLab authentik workspace. Confirm in Authentik Admin that app `seerr` has the two new redirect URIs and launch URL `https://seerr.dominiksiejak.pl`.
