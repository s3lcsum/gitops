# CloudNativePG Shared Postgres Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install local-path + NAS NFS StorageClasses and a shared CloudNativePG `Cluster` (`postgres`) with daily Barman backups to the existing NAS S3 API, while leaving Portainer compose Postgres running.

**Architecture:** Three ApplicationSet sibling apps under `kubernetes/`. Operator + Cluster live in namespace `cloudnative-pg`. App kustomize later owns `Database` / `DatabaseRole` CRs with `metadata.namespace: cloudnative-pg`. Data PVC is 8Gi on `local-path`; NAS NFS SC is available for special volumes only.

**Tech Stack:** containeroo `local-path-provisioner` 0.0.38, kubernetes-sigs `nfs-subdir-external-provisioner` 4.0.18, CNPG Helm `cloudnative-pg` 0.29.1 (app 1.30.1), External Secrets Operator, Synology NAS `192.168.89.240` (NFS + existing S3 API).

**Spec:** `docs/superpowers/specs/2026-09-24-cnpg-shared-postgres-design.md`

## Global Constraints

- Context: `kubectl --context 'k8s@lake'`.
- Single-node lake: every Deployment/Cluster pod needs control-plane toleration `node-role.kubernetes.io/control-plane` Exists/NoSchedule.
- Pin Helm chart versions exactly via ApplicationSet keys `repoURL` / `chart` / `version` at top of each `values.yaml`.
- Compose Postgres on Portainer stays up; do not restore the dump; do not cut over Docker apps.
- Data PVC: `8Gi`, StorageClass `local-path` (default).
- Backups: Barman → existing NAS S3 (`endpointURL` + bucket); never commit S3 keys or dumps.
- Dump already at `~/Backups/postgres/postgres-backup-20260924-080120.sql` (outside git).
- Prune stays off on ApplicationSet children.
- Public repo: no secrets in YAML; Barman creds via ExternalSecret → 1Password.
- Domain / LAN: NAS IP `192.168.89.240`.

## Prerequisites (human, before Task 3–5)

Complete these once; implementer blocks on missing items.

1. **NFS export on Synology** (`192.168.89.240`): create shared folder e.g. `/volume1/k8s-nfs`, enable NFS, allow client `192.168.89.252` (lake) read/write. Record the exact export path.
2. **NAS S3**: create bucket e.g. `cnpg-backups`, access key + secret key with put/get/list/delete on that bucket. Note `endpointURL` (Synology Object Store / MinIO URL, including scheme+port).
3. **1Password item** (Vault used by ESO ClusterSecretStore `onepassword`):
   - Item title: `cnpg-barman-s3`
   - Fields: `ACCESS_KEY_ID`, `ACCESS_SECRET_KEY` (exact key names for ExternalSecret `remoteRef`)
   - Tag: `ArgoCD External Secrets Operator` (same convention as other k8s ESO items)
4. Fill non-secret strings into Cluster manifests when writing them:
   - `ENDPOINT_URL` — e.g. `https://nas.dominiksiejak.pl:9000` (use your real URL)
   - `DESTINATION_PATH` — e.g. `s3://cnpg-backups/postgres/`
   - `NFS_PATH` — exact Synology export path from step 1

## File map

| Path | Responsibility |
|------|----------------|
| `kubernetes/local-path-provisioner/values.yaml` | Chart pin + default `local-path` SC + tolerations |
| `kubernetes/local-path-provisioner/kustomization.yaml` | Empty resources OK |
| `kubernetes/nfs/values.yaml` | Chart pin + NAS server/path + SC `nfs` (non-default) + tolerations |
| `kubernetes/nfs/kustomization.yaml` | Empty resources OK |
| `kubernetes/cloudnative-pg/values.yaml` | Operator chart pin + tolerations; `monitoring.podMonitorEnabled: false` |
| `kubernetes/cloudnative-pg/kustomization.yaml` | Lists `resources/` |
| `kubernetes/cloudnative-pg/resources/externalsecret-barman.yaml` | ESO → Secret `cnpg-barman-s3` |
| `kubernetes/cloudnative-pg/resources/cluster.yaml` | Shared `Cluster` `postgres`, 8Gi, barman, tolerations |
| `kubernetes/cloudnative-pg/resources/scheduledbackup.yaml` | Daily ScheduledBackup |
| `kubernetes/cloudnative-pg/resources/examples/smoke-database.yaml` | Example `DatabaseRole` + `Database` (not listed in kustomization — docs-only) |

---

### Task 1: Scaffold `local-path-provisioner` Argo app

**Files:**
- Create: `kubernetes/local-path-provisioner/values.yaml`
- Create: `kubernetes/local-path-provisioner/kustomization.yaml`

**Interfaces:**
- Consumes: ApplicationSet `kubernetes/*/values.yaml`
- Produces: StorageClass `local-path` (default), provisioner in ns `local-path-provisioner`

- [ ] **Step 1: Write values**

```yaml
# kubernetes/local-path-provisioner/values.yaml
# ApplicationSet chart pin.
repoURL: https://charts.containeroo.ch
chart: local-path-provisioner
version: 0.0.38

# Overrides for containeroo/local-path-provisioner 0.0.38 (app v0.0.37).
replicaCount: 1
tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
storageClass:
  create: true
  defaultClass: true
  name: local-path
  reclaimPolicy: Delete
  volumeBindingMode: WaitForFirstConsumer
  defaultVolumeType: hostPath
nodePathMap:
  - node: DEFAULT_PATH_FOR_NON_LISTED_NODES
    paths:
      - /opt/local-path-provisioner
```

- [ ] **Step 2: Write kustomization**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: []
```

- [ ] **Step 3: Commit**

```bash
git add kubernetes/local-path-provisioner/
git commit -m "$(cat <<'EOF'
feat(k8s): add local-path-provisioner for default StorageClass

EOF
)"
```

- [ ] **Step 4: Push to `main` and wait for ApplicationSet**

```bash
git push origin HEAD
kubectl --context 'k8s@lake' -n argocd get application local-path-provisioner
# Wait until Synced/Healthy (may take 1–2 min after AppSet reconcile)
kubectl --context 'k8s@lake' get sc local-path -o yaml | rg 'is-default-class|provisioner'
```

Expected: StorageClass `local-path` exists; annotation `storageclass.kubernetes.io/is-default-class: "true"`.

---

### Task 2: Scaffold `nfs` Argo app (NAS StorageClass)

**Files:**
- Create: `kubernetes/nfs/values.yaml`
- Create: `kubernetes/nfs/kustomization.yaml`

**Interfaces:**
- Consumes: Prerequisites NFS export path; ApplicationSet
- Produces: StorageClass `nfs` (non-default) in ns `nfs`

- [ ] **Step 1: Confirm NFS export from lake**

```bash
showmount -e 192.168.89.240
# Expect your export path listed (e.g. /volume1/k8s-nfs)
```

- [ ] **Step 2: Write values (substitute `NFS_PATH`)**

```yaml
# kubernetes/nfs/values.yaml
# ApplicationSet chart pin.
repoURL: https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
chart: nfs-subdir-external-provisioner
version: 4.0.18

# Overrides for nfs-subdir-external-provisioner 4.0.18.
replicaCount: 1
tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
nfs:
  server: 192.168.89.240
  path: NFS_PATH   # replace with real export, e.g. /volume1/k8s-nfs
storageClass:
  create: true
  defaultClass: false
  name: nfs
  reclaimPolicy: Delete
  allowVolumeExpansion: true
  accessModes: ReadWriteMany
  volumeBindingMode: Immediate
```

- [ ] **Step 3: Write kustomization**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: []
```

- [ ] **Step 4: Commit, push, verify**

```bash
git add kubernetes/nfs/
git commit -m "$(cat <<'EOF'
feat(k8s): add NAS NFS StorageClass via nfs-subdir provisioner

EOF
)"
git push origin HEAD
kubectl --context 'k8s@lake' -n nfs get pods
kubectl --context 'k8s@lake' get sc nfs
```

Expected: provisioner pod Running; SC `nfs` present; `local-path` still default.

- [ ] **Step 5: Smoke PVC on `nfs` (optional, delete after)**

```bash
kubectl --context 'k8s@lake' apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-smoke
  namespace: nfs
spec:
  accessModes: [ReadWriteMany]
  storageClassName: nfs
  resources:
    requests:
      storage: 1Gi
EOF
kubectl --context 'k8s@lake' -n nfs get pvc nfs-smoke
# Bound → ok; then delete
kubectl --context 'k8s@lake' -n nfs delete pvc nfs-smoke
```

---

### Task 3: Install CloudNativePG operator

**Files:**
- Create: `kubernetes/cloudnative-pg/values.yaml`
- Create: `kubernetes/cloudnative-pg/kustomization.yaml` (resources empty until Task 4)

**Interfaces:**
- Consumes: ApplicationSet
- Produces: CNPG CRDs + operator Deployment in ns `cloudnative-pg`

- [ ] **Step 1: Write operator values**

```yaml
# kubernetes/cloudnative-pg/values.yaml
# ApplicationSet chart pin.
repoURL: https://cloudnative-pg.github.io/charts
chart: cloudnative-pg
version: 0.29.1

# Overrides for cloudnative-pg 0.29.1 (app 1.30.1).
crds:
  create: true
monitoring:
  podMonitorEnabled: false
tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
resources:
  requests:
    cpu: 50m
    memory: 128Mi
```

- [ ] **Step 2: Temporary empty kustomization**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: []
```

- [ ] **Step 3: Commit, push, verify operator**

```bash
git add kubernetes/cloudnative-pg/
git commit -m "$(cat <<'EOF'
feat(k8s): install CloudNativePG operator

EOF
)"
git push origin HEAD
kubectl --context 'k8s@lake' -n cloudnative-pg get deploy,pods
kubectl --context 'k8s@lake' get crd clusters.postgresql.cnpg.io databases.postgresql.cnpg.io
# DatabaseRole CRD name may be databaseroles.postgresql.cnpg.io
kubectl --context 'k8s@lake' get crd | rg cnpg
```

Expected: operator Deployment Available; CRDs for Cluster, Database, DatabaseRole present.

---

### Task 4: Barman ExternalSecret + shared `Cluster` + ScheduledBackup

**Files:**
- Create: `kubernetes/cloudnative-pg/resources/externalsecret-barman.yaml`
- Create: `kubernetes/cloudnative-pg/resources/cluster.yaml`
- Create: `kubernetes/cloudnative-pg/resources/scheduledbackup.yaml`
- Modify: `kubernetes/cloudnative-pg/kustomization.yaml`

**Interfaces:**
- Consumes: 1Password item `cnpg-barman-s3`; SC `local-path`; CNPG operator
- Produces: Secret `cnpg-barman-s3`, Cluster `postgres` Ready, daily ScheduledBackup

- [ ] **Step 1: Confirm 1Password item reachable by ESO** (item + tag from Prerequisites)

- [ ] **Step 2: Write ExternalSecret**

```yaml
# kubernetes/cloudnative-pg/resources/externalsecret-barman.yaml
# 1Password item: cnpg-barman-s3 (fields ACCESS_KEY_ID, ACCESS_SECRET_KEY)
# Tag: ArgoCD External Secrets Operator
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: cnpg-barman-s3
  namespace: cloudnative-pg
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: onepassword
    kind: ClusterSecretStore
  target:
    name: cnpg-barman-s3
    creationPolicy: Owner
    deletionPolicy: Retain
    template:
      engineVersion: v2
      metadata:
        labels: {}
        annotations: {}
  data:
    - secretKey: ACCESS_KEY_ID
      remoteRef:
        key: cnpg-barman-s3/ACCESS_KEY_ID
    - secretKey: ACCESS_SECRET_KEY
      remoteRef:
        key: cnpg-barman-s3/ACCESS_SECRET_KEY
```

- [ ] **Step 3: Write Cluster (substitute `ENDPOINT_URL` and `DESTINATION_PATH`)**

```yaml
# kubernetes/cloudnative-pg/resources/cluster.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres
  namespace: cloudnative-pg
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  instances: 1
  imageName: ghcr.io/cloudnative-pg/postgresql:18
  enableSuperuserAccess: true
  storage:
    size: 8Gi
    storageClass: local-path
  affinity:
    tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
  # Empty shared cluster: keep default app DB as unused canary; apps add Database CRs.
  bootstrap:
    initdb:
      database: app
      owner: app
  backup:
    retentionPolicy: "7d"
    barmanObjectStore:
      destinationPath: DESTINATION_PATH
      endpointURL: ENDPOINT_URL
      s3Credentials:
        accessKeyId:
          name: cnpg-barman-s3
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: cnpg-barman-s3
          key: ACCESS_SECRET_KEY
      wal:
        compression: gzip
      data:
        compression: gzip
```

Notes for implementer:
- If Synology S3 rejects virtual-host style, consult CNPG object-store appendix and Synology docs; adjust `endpointURL` / bucket naming before changing retention.
- If `imageName` tag `18` is unavailable for the operator version, use the chart’s default by omitting `imageName` (prefer pinning an explicit tag once verified with `kubectl explain` / CNPG release notes).
- CNPG creates Secrets `postgres-superuser` and `postgres-app` (names follow Cluster name) with generated passwords.

- [ ] **Step 4: Write ScheduledBackup**

```yaml
# kubernetes/cloudnative-pg/resources/scheduledbackup.yaml
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: postgres-daily
  namespace: cloudnative-pg
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  schedule: "0 0 3 * * *"
  backupOwnerReference: self
  immediate: true
  cluster:
    name: postgres
```

- [ ] **Step 5: Wire kustomization**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - resources/externalsecret-barman.yaml
  - resources/cluster.yaml
  - resources/scheduledbackup.yaml
```

- [ ] **Step 6: Commit, push, wait Ready**

```bash
git add kubernetes/cloudnative-pg/
git commit -m "$(cat <<'EOF'
feat(k8s): add shared CNPG Cluster with NAS S3 Barman backups

EOF
)"
git push origin HEAD
kubectl --context 'k8s@lake' -n cloudnative-pg get externalsecret,secret cnpg-barman-s3
kubectl --context 'k8s@lake' -n cloudnative-pg get cluster postgres -w
# Ctrl-C when STATUS shows Cluster in healthy/ready state
kubectl --context 'k8s@lake' -n cloudnative-pg get pods,pvc,svc
kubectl --context 'k8s@lake' -n cloudnative-pg get backup
```

Expected:
- ExternalSecret Synced; Secret `cnpg-barman-s3` has both keys.
- Pod `postgres-1` Running; PVC Bound 8Gi on `local-path`.
- Services `postgres-rw`, `postgres-r` (or `postgres-ro`) exist.
- At least one `Backup` completes successfully (`phase: completed`) after `immediate: true`.

- [ ] **Step 7: Verify object appears in NAS S3 bucket** (AWS CLI / Synology UI / `mc ls`)

If Backup fails with credential/endpoint errors: fix Secret/endpointURL, do not enlarge scope.

- [ ] **Step 8: Confirm compose Postgres still up**

```bash
ssh portainer 'docker ps --filter name=postgres --format "{{.Names}} {{.Status}}"'
```

Expected: Portainer `postgres` container still healthy.

---

### Task 5: Smoke `DatabaseRole` + `Database` + example manifest

**Files:**
- Create: `kubernetes/cloudnative-pg/resources/examples/smoke-database.yaml` (not in kustomization)
- Apply smoke resources live once, then delete (or leave as retained test DB — prefer delete after verify)

**Interfaces:**
- Consumes: Ready Cluster `postgres`
- Produces: Proof that declarative DB/role works; checked-in example for future apps

- [ ] **Step 1: Create password Secret for smoke role**

```bash
PASS=$(openssl rand -base64 24)
kubectl --context 'k8s@lake' -n cloudnative-pg create secret generic smoke-role-password \
  --type=kubernetes.io/basic-auth \
  --from-literal=username=smoke \
  --from-literal=password="$PASS"
# Save PASS only in your password manager if you keep the role; otherwise discard after delete.
```

- [ ] **Step 2: Apply smoke CRs**

```bash
kubectl --context 'k8s@lake' apply -f - <<'EOF'
apiVersion: postgresql.cnpg.io/v1
kind: DatabaseRole
metadata:
  name: smoke
  namespace: cloudnative-pg
spec:
  cluster:
    name: postgres
  name: smoke
  login: true
  databaseRoleReclaimPolicy: delete
  passwordSecret:
    name: smoke-role-password
---
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: smoke
  namespace: cloudnative-pg
spec:
  name: smoke
  owner: smoke
  cluster:
    name: postgres
EOF
kubectl --context 'k8s@lake' -n cloudnative-pg get databaserole,database
```

Expected: both show applied/ready in status (check `kubectl describe`).

- [ ] **Step 3: Connect via `postgres-rw`**

```bash
kubectl --context 'k8s@lake' -n cloudnative-pg run psql-smoke --rm -it --restart=Never \
  --image=ghcr.io/cloudnative-pg/postgresql:18 \
  --env="PGPASSWORD=$(kubectl --context 'k8s@lake' -n cloudnative-pg get secret smoke-role-password -o jsonpath='{.data.password}' | base64 -d)" \
  -- psql -h postgres-rw.cloudnative-pg.svc -U smoke -d smoke -c 'SELECT current_user, current_database();'
```

Expected: row `smoke | smoke`.

- [ ] **Step 4: Delete smoke objects**

```bash
kubectl --context 'k8s@lake' -n cloudnative-pg delete database smoke databaserole smoke secret smoke-role-password
kubectl --context 'k8s@lake' -n cloudnative-pg delete pod psql-smoke --ignore-not-found
```

- [ ] **Step 5: Check in example (not synced)**

Write `kubernetes/cloudnative-pg/resources/examples/smoke-database.yaml` with the same YAML as Step 2 plus comments:

```yaml
# Example only — NOT listed in kustomization.yaml.
# Copy into an app dir (e.g. kubernetes/authentik/resources/) and set
# metadata.namespace: cloudnative-pg. Provide password Secret via ESO
# (type kubernetes.io/basic-auth, keys username/password).
# Host for apps: postgres-rw.cloudnative-pg.svc:5432
```

Do **not** add this file to `kustomization.yaml`.

- [ ] **Step 6: Commit example**

```bash
git add kubernetes/cloudnative-pg/resources/examples/
git commit -m "$(cat <<'EOF'
docs(k8s): add CNPG Database/DatabaseRole example for app kustomize

EOF
)"
git push origin HEAD
```

---

### Task 6: Spec/plan status + AGENTS.md one-liner

**Files:**
- Modify: `docs/superpowers/specs/2026-09-24-cnpg-shared-postgres-design.md` (status already approved; close open items if resolved)
- Modify: `AGENTS.md` — short note under Architecture that shared k8s Postgres is CNPG in `cloudnative-pg`, compose Postgres still on Portainer

- [ ] **Step 1: Update AGENTS.md Architecture** with 2–3 sentences pointing at `kubernetes/cloudnative-pg` and the Database/DatabaseRole pattern; keep compose Postgres as Docker SoT for stacks.

- [ ] **Step 2: Commit**

```bash
git add AGENTS.md docs/superpowers/specs/2026-09-24-cnpg-shared-postgres-design.md
git commit -m "$(cat <<'EOF'
docs: note CNPG shared Postgres beside compose Postgres

EOF
)"
git push origin HEAD
```

---

## Self-review (plan vs spec)

| Spec requirement | Task |
|------------------|------|
| local-path default SC | Task 1 |
| NAS NFS SC | Task 2 |
| CNPG operator | Task 3 |
| Shared Cluster `postgres`, 8Gi, instances 1 | Task 4 |
| Barman → NAS S3 + ScheduledBackup 7d | Task 4 |
| Compose Postgres untouched + dump not restored | Task 4 Step 8 + Global Constraints |
| App pattern Database + DatabaseRole | Task 5 |
| ESO for Barman secrets | Task 4 |
| Success: backup in bucket + connect smoke | Task 4 Step 7, Task 5 Step 3 |

**Role passwords:** Spec clarified — bootstrap Secrets CNPG-generated; additional roles use basic-auth Secrets (ESO for real apps). Matches Task 5.

**Open human inputs:** `NFS_PATH`, `ENDPOINT_URL`, `DESTINATION_PATH`, 1Password item — Prerequisites, not plan placeholders inside committed logic beyond substitute markers.

---

## Execution handoff

Plan saved to `docs/superpowers/plans/2026-09-24-cnpg-shared-postgres.md`.

**1. Subagent-Driven (recommended)** — fresh subagent per task, review between tasks
**2. Inline Execution** — run tasks in this session with checkpoints

Which approach?
