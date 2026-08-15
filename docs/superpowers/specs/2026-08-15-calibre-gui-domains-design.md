# Calibre GUI Domain — Design (2026-08-15)

## Context

- `calibre.dominiksiejak.pl` serves Calibre-Web-Automated (CWA) — the browser/OPDS automation UI. Sometimes flaky.
- User wants a separate `calibre-gui.dominiksiejak.pl` hosting the **original Calibre desktop app in the browser** as a richer fallback.
- The desktop `calibre` container (linuxserver/calibre:9.13.0) is already deployed, healthy, and serves the full GUI via selkies on port 8080 (nginx → websocket `:8082`). Calibre app process confirmed running.
- Traefik router `calibre-gui@docker` already exists: `Host(calibre-gui.dominiksiejak.pl)` → service `calibre-gui` → container port 8080, with `authentik@docker` forward-auth middleware.

## Root cause

`https://calibre-gui.dominiksiejak.pl` currently returns a 404 **from Authentik** (its styled 404 page). The compose labels + Traefik router are correct; Authentik forward-auth rejects the host because **no Authentik proxy provider is registered for `calibre-gui.dominiksiejak.pl`** — only `calibre.dominiksiejak.pl` is.

## Change

**Decision: Authentik-protected** (keep the existing `authentik@docker` middleware; full desktop app stays behind SSO).

Single change in `terraform/authentik/locals.tf` — add a `calibre-gui` entry to the `proxy_applications` map:

| field            | value |
|------------------|-------|
| `name`           | `Calibre` |
| `slug` / key     | `calibre-gui` |
| `external_host`  | `https://calibre-gui.dominiksiejak.pl` |
| `internal_host`  | `http://calibre:8080` |
| `launch_url`     | `https://calibre-gui.dominiksiejak.pl` |
| `icon_url`       | existing calibre svg (same as `calibre` entry) |
| `skip_path_regex`| `""` |

Then `make plan` + `make apply` in `terraform/authentik/` (OpenTofu, workspace `gitops-authentik`).

## Effects of the apply

- `authentik_provider_proxy.proxy["calibre-gui"]` — new forward_single provider, external host matches the request host → forward-auth accepts it.
- `authentik_application.proxy["calibre-gui"]` — shows in the user library, icon + launch URL.
- `authentik_policy_binding.admin_access` — auto-covered via the existing `all_app_uuids` merge in `applications.tf` → admin-only gating (same as other apps).

No changes to `stacks/calibre/compose.yaml`, Traefik, DNS, or gatus.

## Verification

1. `make plan` in `terraform/authentik/` — expect 1 provider + 1 application + 1 binding created, no drift elsewhere.
2. `make apply`.
3. `curl -skI https://calibre-gui.dominiksiejak.pl` → expect Authentik login redirect (302 to `auth.dominiksiejak.pl/...`), not 404.
4. Browser: log in via Authentik → desktop Calibre GUI loads (selkies frame, websocket connected).

## Rollback

Remove the `calibre-gui` entry from `proxy_applications` in `locals.tf` and re-apply. Container + Traefik untouched.

## Out of scope

- gatus monitor and homepage tile for the GUI (offered; user can request later).