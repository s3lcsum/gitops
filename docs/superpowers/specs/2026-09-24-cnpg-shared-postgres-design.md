# CloudNativePG shared Postgres — design

**Date:** 2026-09-24
**Status:** approved
**Scope:** In-cluster shared PostgreSQL via CloudNativePG, dual StorageClasses, NAS S3 continuous backups; compose Postgres stays up in parallel.

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
| Extra storage | NAS-backed NFS StorageClass for special PVCs only |
| Continuous backup | Barman → **existing NAS S3 API** (`endpointURL` + bucket) |
| HA | `instances: 1` (single-node kubeadm `k8s@lake`) |
| Role passwords | CNPG-generated Secrets; copy into app ns when needed |
| Barman / admin secrets | ExternalSecret ← 1Password |

## Goals

- Install CNPG and a shared `Cluster` named `postgres` in namespace `cloudnative-pg`.
- Provide default `local-path` StorageClass and a separate NAS NFS StorageClass.
- Enable continuous WAL/base backup to NAS S3 from day one (`ScheduledBackup`).
- Document/implement the pattern so an app kustomize can own `Database` + `DatabaseRole` CRs targeting that Cluster.
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
       ──► Cluster "postgres"
              ├─ PVC 8Gi (local-path) on lake LXC
              ├─ Service postgres-rw / postgres-ro (ClusterIP)
              └─ barmanObjectStore → NAS S3 (endpointURL + ESO creds)
                     ScheduledBackup (daily, retain 7d)

Storage:
  local-path-provisioner  → default SC (Cluster data)
  nfs / csi-driver-nfs    → NAS SC (opt-in special volumes)

Compose Postgres (Portainer) ── still running, untouched
```

Lake facts: single node `k8s` / `192.168.89.252`, control-plane taint → all workloads need control-plane toleration. No StorageClass existed at design time.

## GitOps layout

ApplicationSet discovers each `kubernetes/<name>/values.yaml` (except `argocd`).

```
kubernetes/local-path-provisioner/
  values.yaml                 # chart pin; set as default StorageClass
  kustomization.yaml

kubernetes/nfs/               # name may be csi-driver-nfs — pin in plan
  values.yaml                 # NAS server/path → StorageClass (non-default)
  kustomization.yaml

kubernetes/cloudnative-pg/
  values.yaml                 # operator chart pin + lake tolerations
  kustomization.yaml
  resources/
    cluster.yaml              # Cluster postgres, instances:1, local-path, barman
    scheduledbackup.yaml
    externalsecret-barman.yaml
    # optional: resources/examples/database-databaserole.yaml (non-live sample)
```

### Cluster (intent)

- `metadata.name: postgres`, namespace `cloudnative-pg`.
- `spec.instances: 1`.
- Storage: `size: 8Gi`, `storageClass: local-path` (exact SC name from provisioner chart).
- Bootstrap: CNPG default init (empty cluster — no dump restore in phase 1).
- Backup: `spec.backup.barmanObjectStore` with `endpointURL` pointing at NAS S3, `destinationPath` bucket/prefix, credentials from Secret populated by ExternalSecret.
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

1. `DatabaseRole` uses CNPG-generated password Secret in `cloudnative-pg`.
2. When an app needs the URI: Reflector or ExternalSecret copies/mirrors into the app namespace (choose concrete tool in implementation plan; prefer whatever already fits the repo — ESO is present; Reflector is not).
3. Connection host: `postgres-rw.cloudnative-pg.svc`.

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
| Barman S3 access key / secret | 1Password → ExternalSecret (tag consistently with other k8s ESO items) |
| Cluster superuser / app roles | CNPG-managed Secrets in `cloudnative-pg` |
| Dump file | Local only (`~/Backups/postgres/…`); never git |

## Ops defaults

| Knob | Value |
|------|-------|
| Data PVC | 8Gi, `local-path` |
| NAS SC | installed, unused by Cluster in phase 1 |
| ScheduledBackup | daily |
| Retention | 7 days |
| Network | ClusterIP only |
| Cutover | none |

## Risks / gotchas

- **LXC + local-path:** node wipe loses data; Barman/NAS S3 is the recovery path — verify first successful base backup before trusting the Cluster.
- **Public repo:** never commit dumps or raw S3 keys.
- **Cross-ns Argo:** if AppProject is later locked down, app-owned CRs in `cloudnative-pg` need an explicit destination allowlist.
- **DatabaseRole API:** confirm exact CRD/version in the pinned CNPG chart (newer CNPG prefers standalone `DatabaseRole` over inline `managed.roles`).
- **Parallel Postgres:** two servers until cutover — do not point Docker apps at CNPG accidentally.

## Success criteria (phase 1)

1. `local-path` and NAS StorageClasses exist; `local-path` is default.
2. CNPG operator healthy; `Cluster/postgres` Ready with 1 instance.
3. At least one successful Barman backup visible in NAS S3 bucket.
4. Creating a test `Database` + `DatabaseRole` in `cloudnative-pg` (or example path) provisions objects; connect via `postgres-rw` Service.
5. Compose Postgres still up; Docker apps unchanged.

## Open items for implementation plan

- Exact Helm chart repos/versions for local-path-provisioner, NFS CSI/driver, and CNPG.
- NAS S3 `endpointURL`, bucket name, and 1Password item shape (user supplies; not committed).
- NFS server IP/export path for the NAS StorageClass.
- Secret-mirroring mechanism for app namespaces (ESO vs add Reflector).
- Whether `DatabaseRole` is available in the pinned CNPG version or fallback to `spec.managed.roles` on the Cluster for v1.
