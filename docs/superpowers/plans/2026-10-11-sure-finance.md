# Sure Finance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy self-hosted Sure (`sure.dominiksiejak.pl`) as a Kustomize workload with Authentik OIDC, shared CNPG, Valkey, and NFS Active Storage.

**Architecture:** Netbox-shaped manifests under `kubernetes/sure/` auto-Argo Application `application-sure.yaml` (Kustomize-only pattern). Web + Sidekiq + Valkey; CNPG `Database`/`DatabaseRole` in `cloudnative-pg`; secrets via ESO (1Password + `kubernetes-cnpg`); Traefik IngressRoute without forward-auth.

**Tech Stack:** Kubernetes manifests, Argo CD ApplicationSet, CloudNativePG, External Secrets Operator, Traefik, Authentik (OpenTofu), AdGuard rewrites (OpenTofu), image `ghcr.io/we-promise/sure:v0.7.5-hotfix.2`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-10-11-sure-finance-design.md`
- Path: `kubernetes/sure/` only (no Helm, no `application-sure.yaml`)
- Do **not** set top-level `namespace:` on `kustomization.yaml` (cross-ns CNPG resources must keep `cloudnative-pg`)
- Image pin: `ghcr.io/we-promise/sure:v0.7.5-hotfix.2`
- Valkey pin: `ghcr.io/valkey-io/valkey:9.1.2` (match Netbox)
- DB: role `sure_user`, database name `sure_production`, host `postgres-rw.cloudnative-pg.svc`
- OIDC callback: `https://sure.dominiksiejak.pl/auth/openid_connect/callback`
- Auth class: native-oidc (CrowdSec + secure-headers only)
- AI off — no `OPENAI_*`
- Never commit `*.env` / secrets; 1Password item `sure` is manual
- WIP tree reorg may be unstaged — only stage Sure-related paths + listed tofu/docs edits

## File map

| Path | Role |
|------|------|
| `kubernetes/sure/kustomization.yaml` | Resource list |
| `kubernetes/sure/resources/namespace.yaml` | ns `sure` |
| `kubernetes/sure/resources/nfs.yaml` | PV+PVC nas-bind |
| `kubernetes/sure/resources/database.yaml` | CNPG role + DB |
| `kubernetes/sure/resources/externalsecret.yaml` | `sure-user` + `sure` |
| `kubernetes/sure/resources/deployment.yaml` | redis/web/worker + Service |
| `kubernetes/sure/resources/ingressroute.yaml` | Traefik route |
| `terraform/authentik/locals.tf` | OAuth2 app + user_accessible |
| `terraform/adguard/locals.tf` | DNS rewrite |
| `kubernetes/workloads/homepage/config/services.yaml` | Homepage tile |
| `AGENTS.md` | Add `sure` to workloads list |

---

### Task 1: Kustomize app skeleton + CNPG + secrets + NFS

**Files:**
- Create: all under `kubernetes/sure/` listed above except deployment/ingressroute (those Task 2)
- Create: `kustomization.yaml`, `namespace.yaml`, `nfs.yaml`, `database.yaml`, `externalsecret.yaml`

**Interfaces:**
- Produces: Secret `cloudnative-pg/sure-user` (basic-auth), Secret `sure/sure`, PVC `sure-storage`, CNPG `DatabaseRole`/`Database`

- [ ] **Step 1: Write namespace + kustomization + nfs**

`kubernetes/sure/resources/namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: sure
  labels:
    app.kubernetes.io/name: sure
    app.kubernetes.io/part-of: sure
```

`kubernetes/sure/resources/nfs.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: sure-storage
  labels:
    app.kubernetes.io/name: sure
    app.kubernetes.io/part-of: sure
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nas-bind
  mountOptions:
    - nfsvers=4.1
  nfs:
    server: 192.168.89.240
    path: /volume1/media/k8s/sure/storage
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sure-storage
  namespace: sure
  labels:
    app.kubernetes.io/name: sure
    app.kubernetes.io/part-of: sure
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nas-bind
  volumeName: sure-storage
  resources:
    requests:
      storage: 10Gi
```

`kubernetes/sure/kustomization.yaml` (full list after Task 2 files exist; for this task include what exists):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - resources/namespace.yaml
  - resources/nfs.yaml
  - resources/externalsecret.yaml
  - resources/database.yaml
  - resources/deployment.yaml
  - resources/ingressroute.yaml
```

- [ ] **Step 2: Write ExternalSecrets + Database**

`kubernetes/sure/resources/externalsecret.yaml`:

```yaml
# 1Password vault Servers, item sure. Tag: ArgoCD External Secrets Operator
# Fields: SECRET_KEY_BASE, db-password, OIDC_CLIENT_ID, OIDC_CLIENT_SECRET, OIDC_ISSUER
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: sure-user
  namespace: cloudnative-pg
  annotations:
    argocd.argoproj.io/sync-wave: "-2"
spec:
  refreshPolicy: OnChange
  refreshInterval: 0s
  secretStoreRef:
    name: onepassword
    kind: ClusterSecretStore
  target:
    name: sure-user
    creationPolicy: Owner
    deletionPolicy: Retain
    template:
      engineVersion: v2
      type: kubernetes.io/basic-auth
      metadata:
        labels: {}
        annotations:
          argocd.argoproj.io/sync-options: Prune=false
      data:
        username: sure_user
        password: "{{ .password }}"
  data:
    - secretKey: password
      remoteRef:
        key: sure/db-password
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: sure
  namespace: sure
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  refreshPolicy: OnChange
  refreshInterval: 0s
  secretStoreRef:
    name: onepassword
    kind: ClusterSecretStore
  target:
    name: sure
    creationPolicy: Owner
    deletionPolicy: Retain
    template:
      engineVersion: v2
      metadata:
        labels: {}
        annotations:
          argocd.argoproj.io/sync-options: Prune=false
      data:
        SECRET_KEY_BASE: "{{ .secretKeyBase }}"
        POSTGRES_PASSWORD: "{{ .dbPassword }}"
        OIDC_CLIENT_ID: "{{ .oidcClientId }}"
        OIDC_CLIENT_SECRET: "{{ .oidcClientSecret }}"
        OIDC_ISSUER: "{{ .oidcIssuer }}"
        OIDC_REDIRECT_URI: "https://sure.dominiksiejak.pl/auth/openid_connect/callback"
  data:
    - secretKey: secretKeyBase
      remoteRef:
        key: sure/SECRET_KEY_BASE
    - secretKey: oidcClientId
      remoteRef:
        key: sure/OIDC_CLIENT_ID
    - secretKey: oidcClientSecret
      remoteRef:
        key: sure/OIDC_CLIENT_SECRET
    - secretKey: oidcIssuer
      remoteRef:
        key: sure/OIDC_ISSUER
    - secretKey: dbPassword
      sourceRef:
        storeRef:
          kind: ClusterSecretStore
          name: kubernetes-cnpg
      remoteRef:
        key: sure-user
        property: password
```

`kubernetes/sure/resources/database.yaml`:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: DatabaseRole
metadata:
  name: sure-user
  namespace: cloudnative-pg
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  cluster:
    name: postgres
  name: sure_user
  login: true
  databaseRoleReclaimPolicy: delete
  passwordSecret:
    name: sure-user
---
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: sure
  namespace: cloudnative-pg
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  name: sure_production
  owner: sure_user
  cluster:
    name: postgres
```

- [ ] **Step 3: Commit skeleton** (after Task 2 files exist so kustomize validates — prefer single commit with Task 2)

---

### Task 2: Deployments + IngressRoute

**Files:**
- Create: `kubernetes/sure/resources/deployment.yaml`
- Create: `kubernetes/sure/resources/ingressroute.yaml`

**Interfaces:**
- Consumes: Secret `sure`, PVC `sure-storage`, Service name `sure` port 3000
- Produces: Deployments `sure-redis`, `sure-web`, `sure-worker`; Service `sure`

- [ ] **Step 1: Write deployment.yaml**

Full file: Valkey Deployment+Service `sure-redis`; web Deployment with initContainer:

```yaml
initContainers:
  - name: db-prepare
    image: ghcr.io/we-promise/sure:v0.7.5-hotfix.2
    command: ["bash", "-lc"]
    args:
      - |
        until pg_isready -h "$DB_HOST" -p "$DB_PORT"; do echo waiting-db; sleep 5; done
        DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rake db:prepare
    envFrom:
      - secretRef:
          name: sure
    env:
      - name: SELF_HOSTED
        value: "true"
      - name: DB_HOST
        value: postgres-rw.cloudnative-pg.svc
      - name: DB_PORT
        value: "5432"
      - name: POSTGRES_USER
        value: sure_user
      - name: POSTGRES_DB
        value: sure_production
      - name: REDIS_URL
        value: redis://sure-redis:6379/1
```

Web container: same image/env, port 3000, probe `GET /up`, mount PVC at `/rails/storage`, `priorityClassName: homelab-low`, control-plane toleration, strategy Recreate.

Non-secret env on web+worker:

- `SELF_HOSTED=true`
- `ONBOARDING_STATE=open`
- `RAILS_ASSUME_SSL=true`
- `RAILS_FORCE_SSL=false`
- `DB_HOST=postgres-rw.cloudnative-pg.svc`
- `DB_PORT=5432`
- `POSTGRES_USER=sure_user`
- `POSTGRES_DB=sure_production`
- `REDIS_URL=redis://sure-redis:6379/1`
- `WEBAUTHN_RP_ID=sure.dominiksiejak.pl`
- `WEBAUTHN_ALLOWED_ORIGINS=https://sure.dominiksiejak.pl`

Worker: `command: ["bundle", "exec", "sidekiq"]` (or image default Sidekiq entry — use `["bash","-lc","bundle exec sidekiq"]` if needed), same env/volumes, no http probe (omit or use exec true).

Service `sure` → port 3000 target `http`.

Redis: copy Netbox valkey pattern; names `sure-redis`; `homelab-high`.

- [ ] **Step 2: Write ingressroute.yaml**

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: sure
  namespace: sure
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`sure.dominiksiejak.pl`)
      kind: Rule
      middlewares:
        - name: crowdsec-bouncer
          namespace: traefik
        - name: secure-headers
          namespace: traefik
      services:
        - name: sure
          port: 3000
  tls: {}
```

- [ ] **Step 3: Validate**

Run: `kubectl kustomize kubernetes/workloads/sure | rg -n 'kind:|name: sure|sure_production|openid_connect|v0.7.5-hotfix.2|nas-bind'`

Expected: Namespace, ExternalSecrets, DatabaseRole, Database, Deployments, IngressRoute; no top-level rewrite of `cloudnative-pg` resources into `sure`.

- [ ] **Step 4: Commit**

```bash
git add kubernetes/workloads/sure
git commit -m "$(cat <<'EOF'
feat(sure): add Kustomize workload for Sure Finance

Ship web/worker/Valkey, CNPG role+DB, ESO, NFS storage, and Traefik IngressRoute.

EOF
)"
```

---

### Task 3: Authentik + AdGuard + homepage + AGENTS

**Files:**
- Modify: `terraform/authentik/locals.tf` (add `sure` oauth2 + `user_accessible_apps`)
- Modify: `terraform/adguard/locals.tf` (rewrite)
- Modify: `kubernetes/workloads/homepage/config/services.yaml` (tile under Data)
- Modify: `AGENTS.md` (workloads list includes `sure`)

- [ ] **Step 1: Authentik**

In `oauth2_applications`, after `wealthfolio` block, add:

```hcl
    sure = {
      name       = "Sure"
      launch_url = "https://sure.dominiksiejak.pl"
      icon_url   = "https://sure.am/favicon.ico"
      redirect_uris = [
        "https://sure.dominiksiejak.pl/auth/openid_connect/callback",
      ]
    }
```

Add `"sure"` to `user_accessible_apps`.

- [ ] **Step 2: AdGuard**

In `rewrites` map add:

```hcl
    "sure.dominiksiejak.pl"             = "192.168.89.252"
```

(alphabetical near `sonarr` / `status` / `synology` as fits existing order)

- [ ] **Step 3: Homepage**

Under Data, after Wealthfolio:

```yaml
    - Sure:
        icon: https://sure.am/favicon.ico
        href: https://sure.dominiksiejak.pl
        description: Personal finance
```

- [ ] **Step 4: AGENTS.md**

Add `sure` to the `workloads:` bullet list.

- [ ] **Step 5: Commit**

```bash
git add terraform/authentik/locals.tf terraform/adguard/locals.tf \
  kubernetes/workloads/homepage/config/services.yaml AGENTS.md
git commit -m "$(cat <<'EOF'
feat(sure): wire Authentik OIDC, AdGuard rewrite, and homepage tile

EOF
)"
```

---

### Task 4: Manual bootstrap + verify

**Files:** none (ops)

- [ ] **Step 1: Synology** — create share path `/volume1/media/k8s/sure/storage`; confirm NFS export allows `.252`/`.254`.
- [ ] **Step 2: 1Password** — item `sure` in vault Servers, tag `ArgoCD External Secrets Operator`, fields `SECRET_KEY_BASE` (`openssl rand -hex 64`), `db-password` (strong random). Leave OIDC fields empty until Step 4.
- [ ] **Step 3: Merge/push** Sure commits; wait for Argo Application `sure` (may stay Degraded until secrets exist).
- [ ] **Step 4: Terrakube apply `authentik` + `adguard`. Copy `tofu output -json applications | jq -r '.sure'` → fill `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, `OIDC_ISSUER` (`https://auth.dominiksiejak.pl/application/o/sure/`) in 1Password; force ESO refresh if needed.
- [ ] **Step 5: Verify**

```bash
kubectl -n sure get pods,svc,ingressroute,externalsecret,pvc
kubectl -n cloudnative-pg get database sure databaserole sure-user
curl -skI https://sure.dominiksiejak.pl | head
```

Expected: pods Ready; HTTPS 200/302; create local admin; OIDC login works; set onboarding Closed in Sure UI.

---

## Spec coverage checklist

| Spec item | Task |
|-----------|------|
| Kustomize under workloads/sure | 1–2 |
| Image pin hotfix.2 | 2 |
| web/worker/redis priorities | 2 |
| CNPG Database/Role | 1 |
| NFS nas-bind storage | 1 |
| ESO + kubernetes-cnpg password | 1 |
| Rails SSL/self-hosted env | 2 |
| OIDC env + Authentik | 1, 3 |
| IngressRoute native-oidc | 2 |
| AdGuard rewrite | 3 |
| Homepage tile | 3 |
| AI off | 1–2 (omit keys) |
| Manual Synology/1Password/tofu | 4 |
