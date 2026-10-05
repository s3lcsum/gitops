# Terrakube OpenTofu migration

Date: 2026-10-05

## Goal

Run all active OpenTofu roots under `terraform/*` from self-hosted Terrakube:
VCS plan on PR, manual apply in UI, state stored in Terrakube (MinIO), retire
GitHub Actions `terraform.yml`. Per-module secrets. No parallel live GCS backends
after cutover.

## Context

- Terrakube is already GitOps-deployed (`kubernetes/terrakube`, chart `4.7.10`,
  app `2.33.1`): Authentik → Dex OIDC, CNPG DB, Valkey, MinIO on NAS NFS,
  Traefik hosts `terrakube` / `terrakube-api` / `terrakube-reg`.
- Today modules use OpenTofu `1.12.5`, GCS state
  (`dominiksiejak-gitops-tfstate`, prefix `gitops-<dirname>`), and optional
  `workflow_dispatch` CI over WireGuard.
- Compose Postgres on `.253` is gone; app DBs are CNPG. Host `.253` workloads
  moved to `.252`. Drop `terraform/postgres` from this migration (delete/retire
  that tree is a separate chore).
- Executor runs in-cluster on the lake node → LAN targets (RouterOS, UniFi,
  AdGuard, Proxmox) do not need GHA WireGuard.

## Decisions (brainstorming)

| Topic | Choice |
|---|---|
| Scope | All active `terraform/*` modules in one PoC program |
| State | Move into Terrakube storage; leave GCS after cutover |
| Triggers | VCS plan on PR; apply only from Terrakube UI |
| GitHub Actions | Retire `terraform.yml` after path proven |
| Credentials | Per-module Terrakube variables/secrets |
| Layout | One Terrakube org, one workspace per module dir |
| `terraform/postgres` | Out of scope (CNPG replaced it) |

## Architecture

### Organization and workspaces

- Single Terrakube organization (name: `homelab` or `gitops`).
- One workspace per active module directory, same name as the directory.
- Active modules:
  `adguard`, `authentik`, `backblaze`, `cloudflare`, `gcp`, `gitea`,
  `grafana`, `netbox`, `proxmox`, `routeros`, `unifi`.
- Excluded: `postgres`.

### VCS

- Connect this GitHub repo to Terrakube (PAT or GitHub App).
- Each workspace:
  - working directory `terraform/<name>`
  - default branch `main` for apply eligibility
  - OpenTofu `1.12.5` (match `terraform/.opentofu-version`)
  - auto-plan when a PR touches that working directory
  - no auto-apply on merge

### State

- Terrakube remote HTTP backend backed by chart MinIO (`terrakube` bucket /
  existing NFS PVC).
- One-time migrate per module: pull from GCS → Terrakube remote (or
  `tofu init -migrate-state` after backend switch).
- After clean Terrakube plan (empty/no unexpected diff) + one proven apply
  path: remove `backend "gcs"` from that module.
- Keep GCS objects until that gate passes; delete prefixes later.

### Secrets

- Per-workspace Terrakube env/vars only (no shared global bag).
- Source of truth remains 1Password; copy into Terrakube (manual for PoC;
  optional later automation via API).
- Least privilege: each workspace gets only the provider tokens it needs.

### Auth

- UI: existing Authentik app → Dex; admin group `TERRAKUBE_ADMIN`.
- Optional CLI device/login against `terrakube-api` for local plan; apply
  during PoC stays in UI.

### CI retirement

- Disable/delete `.github/workflows/terraform.yml` only after all active
  workspaces have at least one clean Terrakube plan and the apply path is
  proven (default: after wave 4 first success).
- No break-glass GHA kept in parallel.

## Migration waves

Low blast radius first:

1. `netbox`, `gitea`, `backblaze`, `grafana`
2. `gcp`, `cloudflare`
3. `authentik` (after Terrakube login already proven)
4. `adguard`, `proxmox`, `unifi`, `routeros`

### Per-module cutover

1. Create workspace + VCS path + OpenTofu pin.
2. Load per-module secrets/vars.
3. Migrate state GCS → Terrakube.
4. Point module backend at Terrakube; re-init.
5. Plan via PR or UI → require empty / expected-only diff.
6. One manual UI apply to prove the path.
7. Drop GCS backend from module; remove from any remaining GHA module list.
8. Next module.

## Failure handling

- Unexpected non-empty plan → stop; no apply.
- State migrate failure → abort module; GCS remains source of truth.
- Terrakube / MinIO / CNPG down → no applies. Documented break-glass is
  restore GCS backend from git history (not a live dual-path).
- Bad apply → Terrakube run logs + normal OpenTofu recovery; no auto-revert.

## Preconditions (platform)

Terrakube Argo app must be healthy before wave 1:

- CNPG `postgres` Ready (Authentik + Terrakube API depend on it)
- MinIO PVC mounted (`/volume1/media/k8s/terrakube/minio`, UID 1001)
- ExternalSecrets for Terrakube synced (or Retain bootstrap secrets present)
- Dex can reach Authentik OIDC issuer
- API/UI/registry IngressRoutes answering

Known gaps found 2026-10-05 (fix before migrate): NFS path missing (created),
`terrakube_user` had no password / `terrakube-api-secrets` missing (bootstrapped),
CNPG stuck shutting down, 1Password SDK rate-limit on ESO, API startup probe too
tight for cold Spring boot. Durable gitops fixes (passwordSecret wiring, probe,
ESO db ref) land before or with wave 0 platform hardening — not deferred to
module migrate.

## Out of scope

- Deleting `terraform/postgres` tree (separate PR)
- Publishing Terrakube module registry / rewriting roots as thin consumers
- Dual org / domain ACL structure
- Grafana Cloud metrics for Terrakube (optional follow-up)
- Auto-apply on merge

## Success criteria

- All 11 active modules have Terrakube workspaces with remote state
- PR touching a module path produces a Terrakube plan check
- Apply only possible from UI for those workspaces
- No module still using live GCS backend
- `.github/workflows/terraform.yml` removed or disabled
- Empty plan on unchanged `main` for each migrated module
