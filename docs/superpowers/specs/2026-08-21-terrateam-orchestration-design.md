# Stategraph Orchestration (terrateam) control plane

Date: 2026-08-21

## Goal

Self-host the Stategraph Orchestration control plane (formerly Terrateam, `terrat-oss`)
as a new `stacks/terrateam/` stack. It drives plan/apply of the OpenTofu modules in
`terraform/*` from a Web UI/API, with drift detection and scheduled runs, while keeping
the existing GCS state backend untouched. No GitHub/GitLab wiring or hosted tunnel in this
first delivery.

## Context

- Stategraph merged with the former Terrateam. **Stategraph Orchestration** (this target)
  is the continuation of Terrateam: open source, MPL-2.0, GitOps control plane that runs
  plan/apply against your existing Terraform/OpenTofu and state backend. It is **not** the
  Stategraph "Infrastructure as a Database" product (a separate commercial state engine).
- The user explicitly declined the IaC-as-a-Database path, GitHub App/webhook wiring, and
  per-module credential assembly. Decisions taken during brainstorming:
  - DB lives in **central Postgres** (Terraform+Vault), not the bundled `postgres:14.5` from upstream.
  - **Defer all VCS wiring** (GitHub app, webhook, hosted tunnel).
  - Engine gets a **shared GCP service account + secrets env_file** (no per-run Vault lookup).
  - Hostname: **`stategraph.dominiksiejak.pl`** (custom Traefik route; differs from container name).
  - UI gated behind **Authentik OIDC**, admin-only via `groups=admins`, same pattern as hermes-webui.
- Repo: `terraform/*` are OpenTofu modules, state on **GCS** (`backend "gcs"`,
  bucket `dominiksiejak-gitops-tfstate`, prefix `gitops-<dirname>`), `tofu` CLI pinned
  `1.12.5`. Stacks live in `stacks/`, synced to Portainer host `/opt/<stack>/`, Traefik labels.

## Design

### 1. Stack (`stacks/terrateam/`)

Compose file with a single `server` service. No bundled Postgres, no tunnel container.

- `image: ghcr.io/terrateamio/terrat-oss:latest`
- `container_name: terrateam`
- `restart: unless-stopped`
- `env_file: /opt/terrateam/terrateam.env` (secrets, gitignored); `.env.example` committed.
- `environment` (object/map): `DB_HOST=postgres`, `DB_USER=terrateam`, `DB_NAME=terrateam`,
  `TERRAT_UI_BASE=https://stategraph.dominiksiejak.pl`, `TERRAT_WEB_BASE_URL=https://stategraph.dominiksiejak.pl`,
  `TERRAT_API_BASE=https://stategraph.dominiksiejak.pl/api`.
- networks: `proxy`, `database`, `metrics` (all `external: true`), plus
  `traefik.docker.network: proxy`.
- Traefik labels (object syntax):
  - `traefik.enable: true`
  - `traefik.http.services.terrateam.loadbalancer.server.port: 8080`
  - `traefik.http.routers.terrateam.rule: Host(\`stategraph.dominiksiejak.pl\`)`
  - `traefik.http.routers.terrateam.middlewares: authentik@docker` (Authentik forward-auth gate).
- No bundled Postgres; app DB is remote.

### 2. Database (central Postgres)

- Add `terrateam` DB user and DB in `terraform/postgres/locals.tf` + `terraform/vault/locals.tf`.
  This is the postgres modules' pattern for a new DB user.
- Password lives in Vault, fetched via `vault read database/static-creds/terrateam`.
- Apply order: `terraform/postgres` then `terraform/vault`.

### 3. Credentials / engine

- Secrets env file mounted from host (`/opt/terrateam/terrateam.env`), the same pattern as
  other stacks. Contains `DB_*`, `TERRAT_*` URLs, the **GCP service account JSON** for the
  `backend "gcs"`, and a curated set of provider tokens the terraform modules need
  (curated as small as possible to start).
- Engine runs the real OpenTofu modules via the existing `tofu` targets in each
  `terraform/<module>` `Makefile`.
- **Risk:** concentrates multiple credentials in one container. Mitigated by keeping the
  credential list minimal + Authentik admin gate on the UI. Called out explicitly.

### 4. Workspace / module onboarding

- `.terrateam/config.yml` (committed at repo root) treats `terraform/*` modules as
  workspaces with `cmd_type: tofu`, pulling the engine and mounted creds. Drift +
  scheduled checks configured per module.

### 5. Authentication (UI)

- Authentik OIDC in front (forward-auth via the existing `authentik@docker` middleware),
  admin-only via Authentik group membership (groups=admins), the same outward pattern as
  the traefik dashboard gate and the hermes-webui SSO work.

### 6. Portainer integration

- Add `terrateam`, plus `database`/`metrics` net deps, to `terraform/portainer/locals.tf`
  `stacks` list. `apply` (or `sync-portainer`) propagates the stack.

### 7. Consistency + docs

- `scripts/check-consistency.py` auto-adds the homepage + blackbox monitor entry for
  `terrateam.dominiksiejak.pl` (mirror host).
- README service/host table + changelog entry.
- `make check` on affected TF modules; `pre-commit run --all-files`.

## Decisions / trade-offs

- **Central Postgres** over bundled image: single Postgres to maintain, matches repo
  convention. Costs one extra Terraform/Vault provisioning step + DB on `database` net.
- **Defer VCS** (no GitHub App / webhook / tunnel): simpler, fully self-contained first
  delivery. Trade-off: no PR-plan-comment workflow until follow-up; drift/schedule come
  from the in-repo `.terrateam/config.yml` + UI triggers, which still cover the user's goals.
- **Shared SA + env_file** over per-run Vault: simplest live-cloud path; concentrated
  credentials flagged as risk.
- **Custom `stategraph.*` hostname** over `{container.name}`: the container is
  `terrateam` but hosts at `stategraph.dominiksiejak.pl`. Requires an explicit Traefik
  hostname rule (repo allows this when different from default `{service}`).
- **Authentik-sso gate** over local auth: single sign-on, admin-only, consistent with the
  existing hermes-webui pattern. Cost: one extra SSO redirect + claim wiring.

## Deliverables/ files changed (Draft)

- `stacks/terrateam/compose.yaml` (new)
- `stacks/terrateam/terrateam.env.example` (new)
- `stacks/terrateam/.env` (gitignored, generated at deploy)
- `.terrateam/config.yml` (new)
- `.gitignore` (add `**/*.env` already; no change)
- `terraform/postgres/locals.tf` — add terrateam DB user
- `terraform/vault/locals.tf` — add terrateam DB static cred
- `terraform/portainer/locals.tf` + `main.tf` — register stack + networks
- `stacks/homepage/config/services.yaml` (auto-fix)
- `stacks/monitoring/victoria-metrics/promscrape.yaml` (auto-fix)
- `README.md` + changelog

### Explicitly out of scope (follow-ups, not now)
- GitHub App / webhook / PR-plan-comment workflow.
- Full per-module cloud-credential rollout beyond the shared GCP SA.
- Stategraph "Infrastructure as a Database" engine (Path B).

## Verification

- `tofu plan` before `tofu apply` for each touched TF module.
- `make check` (validate + fmt) on postgres / vault / portainer modules.
- `pre-commit run --all-files`.
- After `make apply` portainer: restart `traefik` (routing/middleware) and `terrateam`.
- UI reachable at `https://stategraph.dominiksiejak.pl`, Authentik SSO admin gate returns
  403 for non-`admins`.
