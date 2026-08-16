# Jellyfin Authentik Authentication — Design

**Date:** 2026-08-16
**Status:** Draft (awaiting review)

## Goal

Enable `jellyfin.dominiksiejak.pl` users to authenticate against the self-hosted
Authentik IdP through **both** an OIDC SSO login button and a legacy
LDAP-backed username/password login, using the same Authentik account store.

## Context (verified facts)

- Jellyfin **10.11.11** (linuxserver.io image) in the `mediabox` stack
  (`stacks/mediabox/compose.yaml`), exposed via Traefik at
  `jellyfin.dominiksiejak.pl` on port `8096`.
- Jellyfin `/config` is the named volume `jellyfin_config`. Any files baked into
  the image will *not* appear (volume already initialized) — this rules out
  image-embedded plugins.
- Jellyfin has **no native LDAP or OIDC** support; both require community
  plugins. These are **not** in Jellyfin's default repository, so a gitops
  deploy cannot trigger a web-UI catalog install.
- Authentik already has a `jellyfin` OAuth2 application scaffolded in
  `terraform/authentik/locals.tf` (slug `jellyfin`, redirect
  `https://jellyfin.dominiksiejak.pl/sso/OID/redirect/authentik`) and a shared
  LDAP provider + outpost in `terraform/authentik/ldap.tf`.
- `applications.tf` applies an explicit `grant_types` list (incl.
  `authorization_code`) to every OAuth2 app — required for Jellyfin-SSO.
- Deploy path: `terraform/portainer/` reads `stacks/<name>/compose.yaml` via
  `portainer_stack` (**string method** — no image building, no host commands)
  and `tofu apply` redeploys. `make sync-portainer` rsyncs `stacks/` → `/opt`
  on the Portainer host (`--delete` kept the mirror exact).

## Deploy & access constraint

The user manages infra **only through the gitops repo + tofu/CI** — no direct
shell or web-UI access to the Jellyfin container. All changes must therefore be
expressible as repo content + `make sync-portainer` + `tofu apply` on the
`authentik` and `portainer` workspaces.

## Approach

**Bind-mount checked-in plugin trees** (chosen; no registry/image build).

- Plugin `.dll` trees live in the repo under `stacks/mediabox/jellyfin-plugins/`
  and are bind-mounted into the container at `/config/plugins` (absolute host
  path `/opt/mediabox/jellyfin-plugins`), set in compose.
- Plugin *settings* live separately in individual config XMLs under
  `/config/config/<Plugin>.xml`; these are bind-mounted **as single files** so
  they are gitops-managed without shadowing the rest of `/config/config`.
- Secrets (OIDC client_secret, LDAP bind password) are **injected at sync time
  from Vault/gitignored env**, never committed to the repo.

## Components

### 1. Authentik — OIDC app for the SSO button

- Confirm the `jellyfin` OAuth2 app/provider exists live (`tofu plan` on the
  `authentik` workspace; `locals.tf` is currently uncommitted).
- Add an optional **scope mapping** for `jellyfin` exposing `preferred_username`
  (and `email`) so SSO-created users align with LDAP usernames. The
  `applications.tf` framework already supports a per-app `mapping`.

### 2. Authentik — LDAP for legacy login

- **Reuse** the existing shared `ldap` provider + outpost.
- Create a **technical bind service account** (e.g. `svc_jellyfin`) and set
  `search_group` on the existing LDAP provider so the Jellyfin LDAP plugin can
  search the directory.
- Password validation uses the existing user bind flow
  (`ldap-authentication-flow`) — unchanged.
- **Network wire-up (live-inspection step):** Jellyfin must reach the LDAP
  outpost container. Outpost deploys via the docker-local connection on an
  Authentik-managed network; jellyfin is on `[proxy, arr]`. Plan: identify the
  outpost container name/network and either attach jellyfin to that network or
  expose the outpost's `389/636` to a reachable endpoint.

### 3. Jellyfin — plugin binaries (bind mount)

- `stacks/mediabox/jellyfin-plugins/LdapAuth/` — maintained fork
  `bytegab/jellyfin-ldap-auth`.
- `stacks/mediabox/jellyfin-plugins/bicobus.Jellyfin.Plugin.SSO/` —
  `bicobus/jellyfin-plugin-sso`.
- Compose: add `- /opt/mediabox/jellyfin-plugins:/config/plugins` to the
  `jellyfin` service volumes.

### 4. Jellyfin — plugin config XMLs + secrets

- Bind-mount single config XML files, e.g.:
  - `- /opt/mediabox/jellyfin-ldapauth.xml:/config/config/Jellyfin.Plugin.LdapAuth.xml`
  - `- /opt/mediabox/jellyfin-sso.xml:/config/config/<SSO>.xml`
- Exact plugin config XML names to be confirmed during planning.
- XMLs are rendered from a template at sync time (cf. `v-maintenance` pattern);
  secrets pulled from Vault/gitignored env, so no plaintext secrets in repo.

### 5. Staging, verification & rollback

- **Staging order:** LDAP legacy login first (riskier coexistence partner),
  then SSO on top, then verify coexistence.
- **Verification:** browser automation (playwright) drives
  `jellyfin.dominiksiejak.pl` to test a legacy LDAP username/password login and
  the SSO button flow against Authentik (same method used to verify hermes
  SSO). Plus `tofu plan`/`apply` output on both workspaces.
- **Compatibility pin:** pin SSO + LDAP plugin versions that support Jellyfin
  10.11.11; verify release compatibility during planning.
- **Rollback:** remove the plugins + config-XML bind mounts and `tofu apply`;
  the `/config` named volume is not modified by us, so stock behavior is
  restored cleanly.

## Open items (resolved during planning)

- Exact plugin config XML filenames and directory layout for Jellyfin 10.11.
- Which LDAP plugin release version supports 10.11.11 (maintained fork vs. any
  10.11-specific release).
- Co-existence behavior of LdapAuth + SSO on Jellyfin 10.11's auth-provider
  layer (validate during staging).
- Vault/env plumbing to inject the two plugin secrets into rendered XMLs.

## Files touched

- `stacks/mediabox/compose.yaml` — jellyfin volumes (plugins bind + config XML binds)
- `stacks/mediabox/jellyfin-plugins/` — new checked-in plugin trees
- `stacks/mediabox/jellyfin-*.xml` + template + gitignored secret source
- `terraform/authentik/locals.tf` — jellyfin mapping (scope) if needed
- `terraform/authentik/ldap.tf` — search_group + svc bind account
- `terraform/authentik/identity.tf` — `svc_jellyfin` user/group resources
