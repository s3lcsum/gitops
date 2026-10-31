# Seerr Authentik OIDC Prep — Design

**Date:** 2026-10-31
**Status:** Approved (implementation)

## Goal

Align the existing Authentik OAuth2 application slug `seerr` with the [official Seerr ↔ Authentik redirect URIs](https://integrations.goauthentik.io/media/seerr/), while keeping Seerr on the official stable image. Native OIDC login in Seerr is **out of scope** until upstream ships it in a stable release.

## Context (verified facts)

- Authentik already has `oauth2_applications.seerr` in `terraform/authentik/locals.tf` (slug `seerr`, in `user_accessible_apps`).
- Current redirect URI is the legacy Jellyseerr SSO style:
  `https://seerr.dominiksiejak.pl/login?provider=authentik&callback=true`.
- Current `launch_url` points at `/sso/OID/start/authentik` (same legacy SSO path).
- Official Authentik guide redirect URIs (Strict / Authorization):
  - `https://seerr.dominiksiejak.pl/login`
  - `https://seerr.dominiksiejak.pl/profile/settings/linked-accounts`
- Seerr Deployment (`kubernetes/workloads/mediabox/resources/apps.yaml`) and the live pod both use `ghcr.io/seerr-team/seerr:v3.4.1` — official stable, **not** `preview-new-oidc`.
- Seerr native OIDC remains experimental (`preview-new-oidc` / open PR). Stable `v3.x` has no OIDC settings surface.
- IngressRoute for `seerr.dominiksiejak.pl` has no Authentik forward-auth (public host; app auth only).

## Decision

**Approach A:** Update the existing `seerr` Authentik OAuth2 entry only. Do not change the Seerr image, PVC, or `settings.json`. Do not add Traefik forward-auth.

Rejected alternatives:

- Keep old redirect URI alongside new ones — dead weight; stable Seerr does not use the query-callback form for this IdP prep.
- Switch to `preview-new-oidc` + write Seerr `settings.json` — user chose stay-on-stable.
- Bump to `v3.5.1` in the same change — unrelated version bump; optional later.

## Changes

### 1. `terraform/authentik/locals.tf` — `oauth2_applications.seerr`

| Field | From | To |
|---|---|---|
| `launch_url` | `https://seerr.dominiksiejak.pl/sso/OID/start/authentik` | `https://seerr.dominiksiejak.pl` |
| `redirect_uris` | `…/login?provider=authentik&callback=true` | `…/login` and `…/profile/settings/linked-accounts` |

Unchanged: slug `seerr`, name `Seerr`, `icon_url`, membership in `user_accessible_apps`.

Provider wiring stays via existing `for_each` in `applications.tf` (client id = slug, random secret, strict authorization redirect entries).

### 2. Out of scope

- Seerr container image / tag
- Seerr PVC `/app/config/settings.json` OIDC block
- Mediabox IngressRoute / forward-auth
- Authentik icon swap (`jellyseerr.svg` → seerr) unless trivial and desired later

## Apply path

1. Commit locals change.
2. Terrakube org `HomeLab`, workspace for `terraform/authentik`: remote plan on PR / UI apply.
3. Verify in Authentik Admin: application `seerr` shows the two new redirect URIs; dashboard tile opens `https://seerr.dominiksiejak.pl`.

## Follow-up (not this change)

When Seerr stable includes native OIDC:

1. Optionally bump image pin past the release that includes OIDC.
2. Add Authentik provider to Seerr `settings.json` (`oidcLogin`, issuer `https://auth.dominiksiejak.pl/application/o/seerr/`, client id/secret from `tofu output` on the authentik module).
3. Enable proxy support in Seerr Network settings if needed behind Traefik.

## Success criteria

- `tofu plan` on authentik workspace updates only the `seerr` OAuth2 provider redirect URIs and application launch URL (plus any incidental provider drift already expected).
- Live Seerr image remains `ghcr.io/seerr-team/seerr:v3.4.1` (or whatever official pin is already in gitops — no preview tag).
- Seerr login UX unchanged until the follow-up OIDC enablement.
