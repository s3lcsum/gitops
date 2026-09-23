# Phase for compose `.env` files

**Date:** 2026-09-15
**Status:** Implementation
**Author:** cursor

## Overview

Runtime secrets for Portainer stacks live in gitignored compose `.env` files on
the host (`/opt/<stack>/*.env`). Vault does not inject them — it is a clipboard
for Postgres static-role passwords plus unused PKI and a write-only OAuth KV
dump. Infisical was removed because native OIDC is a paid `LICENSE_KEY` feature.

Replacement is **self-hosted Phase** (`https://phase.dominiksiejak.pl`) with
Authentik OAuth (community env-var SSO, not the Enterprise OIDC SKU). Compose
keeps `env_file:`. `make -C terraform/portainer apply` renders dotenv files from
Phase before rsync.

Vault stays until a later cutover. Phase's own `phase.env` is bootstrap and is
never fetched from Phase. Phase DB is **not** a Vault static role (rotation
would invalidate `phase.env`, same as Infisical).

## Components

- `stacks/phase/` — frontend `phase`, backend, worker, Valkey sidecar, migrate
  oneshot. Traefik `Host(phase.dominiksiejak.pl)`; `/service*` strips to backend
  :8000. No bundled nginx/Postgres. No `authentik@docker`.
- Central Postgres `phase_db` / `phase_user` in `terraform/postgres/locals.tf`
  only. Password: one-time `ALTER USER`, same value in `phase.env`.
- Authentik OAuth2 app slug `phase`, callback
  `https://phase.dominiksiejak.pl/api/auth/callback/authentik`.
- `scripts/phase_env_map.yaml` — one Phase app per compose env file, env `prod`.
- `scripts/render_phase_env.py` — `phase secrets export` into `stacks/*/*.env`.
  Skips when `PHASE_SERVICE_TOKEN` is unset (bootstrap). Fails apply once a
  token is configured and Phase is unreachable.
- `*.env.example` remains the committed key schema.

## Cutover

1. `tofu apply` in `terraform/postgres` (creates `phase_user` / `phase_db` with no password).
2. `ALTER USER phase_user WITH PASSWORD '...'` on Postgres; copy into `/opt/phase/phase.env`.
3. `tofu apply` in `terraform/authentik`; copy `applications.phase.client_secret` into `phase.env`.
4. Write the rest of `phase.env` from `stacks/phase/phase.env.example` (`openssl rand -hex 32` for the three secrets).
5. `make -C terraform/portainer apply` — render-secrets skips (no token yet), stack boots.
6. Sign in with password, then Authentik. Create one Phase app per `scripts/phase_env_map.yaml` entry, env `prod`.
7. From a host that can read live `/opt/*/*.env`: `phase secrets import` each file (`PHASE_HOST=https://phase.dominiksiejak.pl`).
8. Put a service token in `.phase-service-token` (gitignored) or `PHASE_SERVICE_TOKEN`. Later applies render and fail closed if Phase is down.
9. Leave Vault running. Copy `vault read database/static-creds/<user>` into the matching Phase app before disabling rotation.

## Out of scope

- Tearing down Vault / PKI / static-cred rotation for other apps
- `phase run` as container PID 1
- Docker Swarm `secrets:`
