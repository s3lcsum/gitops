# CloudNativePG shared Postgres — design

**Date:** 2026-09-24
**Status:** approved

> **Phase 1a (in gitops today):** CNPG operator + shared `Cluster/postgres` on `local-path` only. **Not installed yet:** NAS NFS StorageClass and Barman/`ScheduledBackup` → NAS S3. Sections below describe full design intent; deferral called out where gitops lags.

**Scope:** In-cluster shared PostgreSQL via CloudNativePG; compose Postgres stays up in parallel. **Delivered in repo (phase 1a):** operator + shared Cluster. **Planned / deferred:** second StorageClass (NAS NFS), continuous backup (Barman → NAS S3).

## Context

Homelab GitOps already runs Argo CD ApplicationSet children under `kubernetes/*/values.yaml`. Central SQL today is Docker Postgres on Portainer (`192.168.89.253`, bind `127.0.0.1:5432`), with roles/DBs from `terraform/postgres`. No SQL operator exists in the cluster.

Goal: k8s apps (e.g. future Authentik-in-k8s) declare `Database` / `DatabaseRole` in their kustomize and get provisioned on one shared in-cluster Postgres — without cutting over Docker apps yet.

**Pre-work done:** full `pg_dumpall` saved outside the public repo at `~/Backups/postgres/postgres-backup-20260924-080120.sql` (~280MB; contains SCRAM hashes — do not commit).

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Operator | CloudNativePG (CNPG) |
| Topology | One shared `Cluster` for all k8s apps |
| Compose Postgres | Remains up; no restore/cutover in phase 1 |
| Data storage | `local-path` on lake LXC disk (default SC) |
| Extra storage | NAS-backed NFS StorageClass for special PVCs only *(planned — not in gitops)* |
| Continuous backup | Barman → **existing NAS S3 API** (`endpointURL` + bucket) *(planned — not in gitops)* |
| HA | `instances: 1` (single-node kubeadm `k8s@lake`) |
| Role passwords | Cluster bootstrap Secrets are CNPG-generated; additional `DatabaseRole` passwords are `kubernetes.io/basic-auth` Secrets (ESO ← 1Password for real apps) |
| Barman / admin secrets | ExternalSecret ← 1Password *(when backup task lands)* |

## Goals

- Install CNPG and a shared `Cluster` named `postgres` in namespace `cloudnative-pg`. *(done in gitops.)*
- Provide default `local-path` StorageClass *(done)* and, when resumed, a separate NAS NFS StorageClass *(deferred)*.
- When backup work resumes: continuous WAL/base backup to NAS S3 via `ScheduledBackup` + Barman *(deferred — not day-one in repo)*.
- Document/implement the pattern so an app kustomize can own `Database` + `DatabaseRole` CRs targeting that Cluster. *(example manifest only.)*
- Keep Portainer compose Postgres running and authoritative for existing Docker stacks.

## Non-goals (phase 1)

- Restoring the dump into CNPG.
- Migrating Authentik / other compose apps off Portainer Postgres.
- Per-app Clusters or multi-instance HA.
- In-cluster MinIO (NAS already exposes S3).
- LAN exposure of Postgres beyond ClusterIP Services.
- Replacing `terraform/postgres` for Docker-side roles.

## Architecture

```
App kustomize (e.g. kubernetes/authentik/)
  └─ Database + DatabaseRole
       metadata.namespace: cloudnative-pg   # same ns as Cluster (CNPG requirement)
       ──► Cluster "postgres"                    [live in gitops]
              ├─ PVC 8Gi (local-path) on lake LXC
              ├─ Service postgres-rw / postgres-ro (ClusterIP)
              └─ (planned) barmanObjectStore → NAS S3 + ScheduledBackup

Storage:
  local-path-provisioner  → default SC (Cluster data)     [live]
  nfs / csi-driver-nfs    → NAS SC (opt-in)                 [deferred]

Compose Postgres (Portainer) ── still running, untouched
```

Lake facts: single node `k8s` / `192.168.89.252`, control-plane taint → all workloads need control-plane toleration. No StorageClass existed at design time.

## GitOps layout

ApplicationSet discovers each `kubernetes/<name>/values.yaml` (except `argocd`).

```
kubernetes/local-path-provisioner/
  values.yaml                 # chart pin; set as default StorageClass
  kustomization.yaml

kubernetes/nfs/               # deferred — not in repo yet
  values.yaml                 # NAS server/path → StorageClass (non-default)
  kustomization.yaml

kubernetes/cloudnative-pg/
  values.yaml                 # operator chart pin + lake tolerations
  kustomization.yaml
  resources/
    cluster.yaml              # Cluster postgres, instances:1, local-path (no backup block yet)
    # deferred: scheduledbackup.yaml, externalsecret-barman.yaml
    # optional: resources/examples/database-databaserole.yaml (non-live sample)
```

### Cluster (intent)

- `metadata.name: postgres`, namespace `cloudnative-pg`.
- `spec.instances: 1`.
- Storage: `size: 8Gi`, `storageClass: local-path` (exact SC name from provisioner chart).
- Bootstrap: CNPG default init (empty cluster — no dump restore in phase 1).
- Backup *(deferred):* `spec.backup.barmanObjectStore` with `endpointURL` pointing at NAS S3, `destinationPath` bucket/prefix, credentials from Secret populated by ExternalSecret — not on committed Cluster yet.
- Tolerations: `node-role.kubernetes.io/control-plane` Exists/NoSchedule.
- Monitoring: defer unless trivial; out of critical path.

### App-owned Database / Role pattern

CNPG requires `Database` / `DatabaseRole` in the **same namespace** as the Cluster.

Apps still “own” the YAML in their directory; they set:

```yaml
metadata:
  namespace: cloudnative-pg
spec:
  cluster:
    name: postgres
```

Argo CD Application destination remains the app namespace; cross-namespace resources are allowed by the default AppProject (confirm in plan if project is restricted later).

Password flow:

1. Cluster bootstrap: CNPG generates `postgres-superuser` / `postgres-app` (or equivalent) Secrets.
2. Additional `DatabaseRole`: provide a `kubernetes.io/basic-auth` Secret (`username` / `password`) in `cloudnative-pg` — for real apps via ExternalSecret ← 1Password; reference it from `spec.passwordSecret`.
3. When an app needs the URI in its own namespace: ESO (preferred; already in-cluster) or a future mirror copies the Secret; host `postgres-rw.cloudnative-pg.svc`.

Example (illustrative):

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: DatabaseRole
metadata:
  name: authentik
  namespace: cloudnative-pg
spec:
  # fields per installed CNPG API — pin exact schema in plan
  # cluster.name: postgres, login: true, generated password Secret
---
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: authentik
  namespace: cloudnative-pg
spec:
  name: authentik
  owner: authentik
  cluster:
    name: postgres
```

Phase 1 does **not** deploy Authentik to k8s; only establishes Cluster + operator + the pattern.

## Secrets

| Secret | Source |
|--------|--------|
| Barman S3 access key / secret | 1Password → ExternalSecret *(when backup task lands)* |
| Cluster superuser / app roles | CNPG-managed Secrets in `cloudnative-pg` |
| Dump file | Local only (`~/Backups/postgres/…`); never git |

## Ops defaults

| Knob | Value |
|------|-------|
| Data PVC | 8Gi, `local-path` |
| NAS SC | planned; not installed — Cluster uses `local-path` only |
| ScheduledBackup | planned (daily) — not in gitops |
| Retention | 7 days (target when Barman lands) |
| Network | ClusterIP only |
| Cutover | none |

## Risks / gotchas

- **LXC + local-path:** node wipe loses data; Barman/NAS S3 is the intended recovery path once backup is wired — until then, treat Cluster data as non-durable for disaster recovery.
- **Public repo:** never commit dumps or raw S3 keys.
- **Cross-ns Argo:** if AppProject is later locked down, app-owned CRs in `cloudnative-pg` need an explicit destination allowlist.
- **DatabaseRole API:** confirm exact CRD/version in the pinned CNPG chart (newer CNPG prefers standalone `DatabaseRole` over inline `managed.roles`).
- **Parallel Postgres:** two servers until cutover — do not point Docker apps at CNPG accidentally.

## Success criteria (phase 1)

1. `local-path` default StorageClass exists. *(done — `kubernetes/local-path-provisioner`.)* NAS StorageClass **deferred** (implementation skipped).
2. CNPG operator healthy; `Cluster/postgres` Ready with 1 instance. *(manifests in `kubernetes/cloudnative-pg`; verify in cluster.)*
3. At least one successful Barman backup visible in NAS S3 bucket. **Deferred** — no `barmanObjectStore` / `ScheduledBackup` / Barman ExternalSecret in gitops yet.
4. Creating a test `Database` + `DatabaseRole` in `cloudnative-pg` (or example path) provisions objects; connect via `postgres-rw` Service. *(pattern documented in `resources/examples/smoke-database.yaml`; smoke not wired in kustomize.)*
5. Compose Postgres still up; Docker apps unchanged. *(unchanged by design.)*

## Implementation status (gitops, 2026-09-24)

| Item | Status |
|------|--------|
| `local-path-provisioner` (default SC) | Committed |
| CNPG operator + `Cluster/postgres` | Committed (no backup block on Cluster) |
| NAS NFS StorageClass | **Skipped** — not in repo |
| Barman → NAS S3 + `ScheduledBackup` + ESO | **Skipped** — not in repo |
| App `Database` / `DatabaseRole` pattern | Example only (`resources/examples/`) |

## Open items

- NAS NFS StorageClass (server/export) — deferred until Task 2 resumed.
- Barman: NAS S3 `endpointURL`, bucket/`destinationPath`, 1Password item → ExternalSecret + `ScheduledBackup` — deferred until backup task resumed.
- Secret-mirroring mechanism for app namespaces (ESO vs Reflector) when first real k8s app needs DB creds outside `cloudnative-pg`.
- Cluster smoke: apply example CRs or app-owned CRs and verify connect via `postgres-rw` (manual/ops).
