# OpenBao Secrets Platform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy OpenBao Phase 1 — Raft single-node, Shamir unseal via 1Password+ESO, Authentik OIDC UI at `openbao.dominiksiejak.pl`, and ready (unused) `ClusterSecretStore/openbao` — while 1Password ESO stays primary.

**Architecture:** ApplicationSet Helm chart `openbao/openbao` `0.30.3` + Kustomize overlays (IngressRoute, ExternalSecrets, unseal CronJob, ESO SA, ClusterSecretStore). Authentik OAuth2 + AdGuard rewrite via OpenTofu. One-time manual `bao operator init` + auth bootstrap; CronJob keeps it unsealed.

**Tech Stack:** OpenBao `v2.7.1` (chart appVersion), ESO `external-secrets.io/v1`, Traefik IngressRoute, Authentik OIDC, AdGuard rewrites, OpenTofu modules `authentik` / `adguard`.

**Spec:** `docs/superpowers/specs/2026-10-10-openbao-secrets-design.md`

## Global Constraints

- Product: OpenBao (not HashiCorp Vault OSS)
- Consumers: ESO only; no Agent/CSI; no ExternalSecret store flips
- Unseal: Shamir keys from 1Password item `Servers` / `openbao` via ESO → CronJob
- Topology: `server.ha.enabled=true`, `replicas: 1`, `ha.raft.enabled=true`, PVC `local-path` 10Gi
- Host: `openbao.dominiksiejak.pl`, native-oidc (crowdsec + secure-headers only)
- Priority: `homelab-critical`; pin control-plane
- Chart pin: `repoURL: https://openbao.github.io/openbao-helm`, `chart: openbao`, `version: 0.30.3`
- Never commit secrets / `*.tfvars` / root token / unseal keys
- Argo ApplicationSet tracks `main` — push required for cluster sync

## File map

| Path | Role |
|------|------|
| `kubernetes/openbao/values.yaml` | Chart pin + server/injector overrides |
| `kubernetes/openbao/kustomization.yaml` | Dir source for ApplicationSet |
| `kubernetes/openbao/resources/ingressroute.yaml` | Traefik edge |
| `kubernetes/openbao/resources/externalsecret-unseal.yaml` | Shamir keys from 1P |
| `kubernetes/openbao/resources/externalsecret-oidc.yaml` | OIDC client secret from 1P (for bootstrap Job/docs; optional mount) |
| `kubernetes/openbao/resources/unseal-cronjob.yaml` | SA + Role + CronJob unsealer |
| `kubernetes/openbao/resources/eso-openbao-sa.yaml` | SA in `external-secrets` for K8s auth |
| `kubernetes/openbao/resources/clustersecretstore.yaml` | `ClusterSecretStore/openbao` |
| `kubernetes/openbao/resources/bootstrap-notes.yaml` | ConfigMap runbook (init/OIDC/K8s auth) |
| `terraform/authentik/locals.tf` | `oauth2_applications.openbao` |
| `terraform/adguard/locals.tf` | DNS rewrite |
| `CHANGELOG.md` | Short Phase 1 note |

---

### Task 1: Helm values + Kustomize skeleton

**Files:**
- Create: `kubernetes/openbao/values.yaml`
- Create: `kubernetes/openbao/kustomization.yaml`

**Interfaces:**
- Produces: ApplicationSet-discoverable app name `openbao` (dir under `kubernetes/`)
- Produces: Helm release name `openbao`, destination ns `openbao`

- [ ] **Step 1: Write `values.yaml`**

```yaml
# ApplicationSet chart pin.
repoURL: https://openbao.github.io/openbao-helm
chart: openbao
version: 0.30.3

# Overrides for openbao/openbao 0.30.3 (appVersion v2.7.1).
# Single-node Raft. Traefik terminates TLS. Injector/CSI off (ESO-only consumers).
global:
  enabled: true
  tlsDisable: true

injector:
  enabled: false

csi:
  enabled: false

server:
  enabled: true
  priorityClassName: homelab-critical
  extraLabels:
    app.kubernetes.io/part-of: openbao
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      memory: 512Mi
  # Replace chart default podAntiAffinity with control-plane pin (single-node lake).
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: node-role.kubernetes.io/control-plane
                operator: Exists
  tolerations:
    - key: node-role.kubernetes.io/control-plane
      operator: Exists
      effect: NoSchedule
  dataStorage:
    enabled: true
    size: 10Gi
    storageClass: local-path
  authDelegator:
    enabled: true
  standalone:
    enabled: false
  ha:
    enabled: true
    replicas: 1
    raft:
      enabled: true
      setNodeId: true
  service:
    enabled: true
    active:
      enabled: true

ui:
  enabled: true
  serviceType: ClusterIP
```

- [ ] **Step 2: Write `kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - resources/ingressroute.yaml
  - resources/externalsecret-unseal.yaml
  - resources/externalsecret-oidc.yaml
  - resources/unseal-cronjob.yaml
  - resources/eso-openbao-sa.yaml
  - resources/clustersecretstore.yaml
  - resources/bootstrap-notes.yaml
```

- [ ] **Step 3: Commit**

```bash
git add kubernetes/openbao/values.yaml kubernetes/openbao/kustomization.yaml
git commit -m "$(cat <<'EOF'
feat(openbao): add Helm values and kustomize skeleton

Pin openbao chart 0.30.3 with single-node Raft for the secrets platform Phase 1.
EOF
)"
```

---

### Task 2: IngressRoute + AdGuard rewrite

**Files:**
- Create: `kubernetes/openbao/resources/ingressroute.yaml`
- Modify: `terraform/adguard/locals.tf` (add rewrite key)

**Interfaces:**
- Consumes: Service `openbao` (or `openbao-active` if active-only — prefer main `openbao` ClusterIP on port `8200`; verify after chart render)
- Produces: `https://openbao.dominiksiejak.pl` → OpenBao UI/API

- [ ] **Step 1: Write IngressRoute**

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: openbao
  namespace: openbao
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`openbao.dominiksiejak.pl`)
      kind: Rule
      middlewares:
        - name: crowdsec-bouncer
          namespace: traefik
        - name: secure-headers
          namespace: traefik
      services:
        - name: openbao
          port: 8200
  tls: {}
```

If chart active service is required for HA labeling with 1 replica and `openbao` does not select pods, switch `name:` to `openbao-ui` (UI service) or `openbao-active` after `kubectl get svc -n openbao`.

- [ ] **Step 2: Add AdGuard rewrite**

In `terraform/adguard/locals.tf` `rewrites` map, add alphabetically near other `o*` entries:

```hcl
    "openbao.dominiksiejak.pl"          = "192.168.89.252"
```

- [ ] **Step 3: Commit**

```bash
git add kubernetes/openbao/resources/ingressroute.yaml terraform/adguard/locals.tf
git commit -m "$(cat <<'EOF'
feat(openbao): expose UI via Traefik and AdGuard rewrite

Route openbao.dominiksiejak.pl to the OpenBao service on the lake edge.
EOF
)"
```

---

### Task 3: Unseal ExternalSecret + CronJob

**Files:**
- Create: `kubernetes/openbao/resources/externalsecret-unseal.yaml`
- Create: `kubernetes/openbao/resources/unseal-cronjob.yaml`

**Interfaces:**
- Consumes: 1Password item `openbao` fields `unseal-key-1`, `unseal-key-2`, `unseal-key-3` (threshold 3; create item after init)
- Produces: Secret `openbao-unseal` in ns `openbao`; CronJob keeps seal status unsealed

- [ ] **Step 1: ExternalSecret for keys**

```yaml
# 1Password vault Servers. Tag: ArgoCD External Secrets Operator
# Item openbao. Fields unseal-key-1..3 written after bao operator init.
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: openbao-unseal
  namespace: openbao
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  refreshPolicy: OnChange
  refreshInterval: 0s
  secretStoreRef:
    name: onepassword
    kind: ClusterSecretStore
  target:
    name: openbao-unseal
    creationPolicy: Owner
    deletionPolicy: Retain
    template:
      engineVersion: v2
      metadata:
        labels: {}
        annotations:
          argocd.argoproj.io/sync-options: Prune=false
  data:
    - secretKey: unseal-key-1
      remoteRef:
        key: openbao/unseal-key-1
    - secretKey: unseal-key-2
      remoteRef:
        key: openbao/unseal-key-2
    - secretKey: unseal-key-3
      remoteRef:
        key: openbao/unseal-key-3
```

- [ ] **Step 2: Unseal CronJob**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: openbao-unseal
  namespace: openbao
  labels:
    app.kubernetes.io/name: openbao-unseal
    app.kubernetes.io/part-of: openbao
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: openbao-unseal
  namespace: openbao
  labels:
    app.kubernetes.io/name: openbao-unseal
    app.kubernetes.io/part-of: openbao
spec:
  schedule: "*/2 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 1
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 1
      template:
        metadata:
          labels:
            app.kubernetes.io/name: openbao-unseal
            app.kubernetes.io/part-of: openbao
        spec:
          serviceAccountName: openbao-unseal
          restartPolicy: OnFailure
          priorityClassName: homelab-low
          tolerations:
            - key: node-role.kubernetes.io/control-plane
              operator: Exists
              effect: NoSchedule
          containers:
            - name: unseal
              image: quay.io/openbao/openbao:2.7.1
              imagePullPolicy: IfNotPresent
              env:
                - name: BAO_ADDR
                  value: http://openbao.openbao.svc:8200
                - name: UNSEAL_KEY_1
                  valueFrom:
                    secretKeyRef:
                      name: openbao-unseal
                      key: unseal-key-1
                      optional: true
                - name: UNSEAL_KEY_2
                  valueFrom:
                    secretKeyRef:
                      name: openbao-unseal
                      key: unseal-key-2
                      optional: true
                - name: UNSEAL_KEY_3
                  valueFrom:
                    secretKeyRef:
                      name: openbao-unseal
                      key: unseal-key-3
                      optional: true
              command:
                - /bin/sh
                - -ec
                - |
                  status_json="$(bao status -format=json 2>/dev/null || true)"
                  if [ -z "$status_json" ]; then
                    echo "openbao not ready; skip"
                    exit 0
                  fi
                  case "$status_json" in
                    *"\"initialized\":false"*|*"\"initialized\": false"*)
                      echo "not initialized; skip"
                      exit 0
                      ;;
                  esac
                  case "$status_json" in
                    *"\"sealed\":false"*|*"\"sealed\": false"*)
                      echo "already unsealed"
                      exit 0
                      ;;
                  esac
                  if [ -z "${UNSEAL_KEY_1:-}" ] || [ -z "${UNSEAL_KEY_2:-}" ] || [ -z "${UNSEAL_KEY_3:-}" ]; then
                    echo "sealed but unseal keys missing; waiting for ExternalSecret"
                    exit 0
                  fi
                  bao operator unseal "$UNSEAL_KEY_1"
                  bao operator unseal "$UNSEAL_KEY_2"
                  bao operator unseal "$UNSEAL_KEY_3"
                  bao status
```

- [ ] **Step 3: Commit**

```bash
git add kubernetes/openbao/resources/externalsecret-unseal.yaml kubernetes/openbao/resources/unseal-cronjob.yaml
git commit -m "$(cat <<'EOF'
feat(openbao): add 1Password-backed Shamir unseal CronJob

Pull three unseal key shares via ESO and unseal every two minutes when sealed.
EOF
)"
```

---

### Task 4: ESO SA + ClusterSecretStore + OIDC ExternalSecret + runbook ConfigMap

**Files:**
- Create: `kubernetes/openbao/resources/eso-openbao-sa.yaml`
- Create: `kubernetes/openbao/resources/clustersecretstore.yaml`
- Create: `kubernetes/openbao/resources/externalsecret-oidc.yaml`
- Create: `kubernetes/openbao/resources/bootstrap-notes.yaml`

**Interfaces:**
- Produces: SA `external-secrets/eso-openbao`; store `ClusterSecretStore/openbao` → `http://openbao.openbao.svc:8200`, KV `secret/`, role `eso-openbao`
- Consumes (later bootstrap): OpenBao K8s auth role bound to that SA

- [ ] **Step 1: SA**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: eso-openbao
  namespace: external-secrets
  labels:
    app.kubernetes.io/name: eso-openbao
    app.kubernetes.io/part-of: openbao
```

- [ ] **Step 2: ClusterSecretStore**

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: openbao
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  provider:
    vault:
      server: http://openbao.openbao.svc:8200
      path: secret
      version: v2
      auth:
        kubernetes:
          mountPath: kubernetes
          role: eso-openbao
          serviceAccountRef:
            name: eso-openbao
            namespace: external-secrets
```

Expect `Ready=False` until OpenBao is initialized, unsealed, and K8s auth + role exist. That is OK for Phase 1.

- [ ] **Step 3: OIDC ExternalSecret**

```yaml
# 1Password vault Servers. Tag: ArgoCD External Secrets Operator
# Item openbao. Fields oidc-client-id / oidc-client-secret from authentik tofu output.
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: openbao-oidc
  namespace: openbao
spec:
  refreshPolicy: OnChange
  refreshInterval: 0s
  secretStoreRef:
    name: onepassword
    kind: ClusterSecretStore
  target:
    name: openbao-oidc
    creationPolicy: Owner
    deletionPolicy: Retain
    template:
      engineVersion: v2
      metadata:
        labels: {}
        annotations:
          argocd.argoproj.io/sync-options: Prune=false
  data:
    - secretKey: client-id
      remoteRef:
        key: openbao/oidc-client-id
    - secretKey: client-secret
      remoteRef:
        key: openbao/oidc-client-secret
```

- [ ] **Step 4: Bootstrap ConfigMap runbook**

Create `bootstrap-notes.yaml` ConfigMap `openbao-bootstrap` in ns `openbao` with data key `RUNBOOK.md` containing these exact command blocks (operator runs manually):

```markdown
# OpenBao bootstrap

## 1. Init (once)
kubectl exec -n openbao openbao-0 -- bao operator init -key-shares=5 -key-threshold=3

Store unseal-key-1..3 (any 3 of 5) and root token in 1Password Servers/openbao.
Force-sync: kubectl annotate externalsecret openbao-unseal -n openbao force-sync=$(date +%s) --overwrite

## 2. KV + Kubernetes auth
export BAO_ADDR=http://127.0.0.1:8200
kubectl exec -n openbao openbao-0 -- bao login  # root token
kubectl exec -n openbao openbao-0 -- bao secrets enable -path=secret kv-v2
kubectl exec -n openbao openbao-0 -- bao auth enable kubernetes

# From a pod with SA token review rights (openbao server SA has authDelegator):
kubectl exec -n openbao openbao-0 -- sh -c 'bao write auth/kubernetes/config \
  kubernetes_host=https://kubernetes.default.svc:443 \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token'

kubectl exec -n openbao openbao-0 -- bao policy write eso - <<'EOF'
path "secret/data/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/*" {
  capabilities = ["read", "list"]
}
EOF

kubectl exec -n openbao openbao-0 -- bao write auth/kubernetes/role/eso-openbao \
  bound_service_account_names=eso-openbao \
  bound_service_account_namespaces=external-secrets \
  policies=eso \
  ttl=1h

## 3. OIDC (Authentik)
# Issuer: https://auth.dominiksiejak.pl/application/o/openbao/
# Client id/secret from tofu output → 1Password → Secret openbao-oidc

kubectl exec -n openbao openbao-0 -- bao auth enable oidc
kubectl exec -n openbao openbao-0 -- bao write auth/oidc/config \
  oidc_discovery_url="https://auth.dominiksiejak.pl/application/o/openbao/" \
  oidc_client_id="$CLIENT_ID" \
  oidc_client_secret="$CLIENT_SECRET" \
  default_role="admin"

kubectl exec -n openbao openbao-0 -- bao policy write admin - <<'EOF'
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF

kubectl exec -n openbao openbao-0 -- bao write auth/oidc/role/admin \
  bound_audiences="$CLIENT_ID" \
  allowed_redirect_uris="https://openbao.dominiksiejak.pl/ui/vault/auth/oidc/oidc/callback" \
  user_claim="sub" \
  groups_claim="groups" \
  policies="admin" \
  oidc_scopes="openid,profile,email" \
  claim_mappings="group=groups"
```

Tune OIDC role/`bound_claims` for Authentik `admins` group once discovery works; keep admin policy on a role that only Authentik admins can obtain (Authentik app already admins-only via policy binding).

- [ ] **Step 5: Commit**

```bash
git add kubernetes/openbao/resources/
git commit -m "$(cat <<'EOF'
feat(openbao): add ESO store, OIDC secret wiring, bootstrap runbook

ClusterSecretStore/openbao and eso-openbao SA are ready for later cutover.
EOF
)"
```

---

### Task 5: Authentik OAuth2 app

**Files:**
- Modify: `terraform/authentik/locals.tf` (`oauth2_applications` map)

**Interfaces:**
- Produces: Authentik app slug `openbao`, issuer `https://auth.dominiksiejak.pl/application/o/openbao/`
- Produces: `tofu output` client id/secret → 1Password fields `oidc-client-id` / `oidc-client-secret`

- [ ] **Step 1: Add map entry** (after `n8n` or alphabetically near other apps — keep map style consistent; insert after `netbox` or at end before closing `}` of `oauth2_applications`):

```hcl
    openbao = {
      name          = "OpenBao"
      launch_url    = "https://openbao.dominiksiejak.pl"
      icon_url      = "https://raw.githubusercontent.com/openbao/artwork/refs/heads/main/color/openbao-color.svg"
      redirect_uris = [
        "https://openbao.dominiksiejak.pl/ui/vault/auth/oidc/oidc/callback",
      ]
    }
```

Do **not** add `openbao` to `user_accessible_apps`.

- [ ] **Step 2: Validate**

```bash
cd terraform/authentik && make check
```

Expected: fmt + validate OK.

- [ ] **Step 3: Commit**

```bash
git add terraform/authentik/locals.tf
git commit -m "$(cat <<'EOF'
feat(authentik): add OpenBao OIDC application

Admins-only OAuth2 app for openbao.dominiksiejak.pl UI login.
EOF
)"
```

- [ ] **Step 4: Apply (operator / Terrakube UI)**

Plan+apply `terraform/authentik` workspace. Copy client id/secret into 1Password `Servers` / `openbao`.

---

### Task 6: Docs + CHANGELOG

**Files:**
- Modify: `CHANGELOG.md` (top entry)
- Modify: `AGENTS.md` — one bullet under Data and secrets: OpenBao Phase 1 lives at `kubernetes/openbao`; app secrets still 1Password until cutover

- [ ] **Step 1: CHANGELOG blurb**

```markdown
**OpenBao Phase 1.** `kubernetes/openbao` deploys OpenBao (Raft×1) at
`openbao.dominiksiejak.pl` with Authentik OIDC and Shamir unseal keys from
1Password. `ClusterSecretStore/openbao` is Ready for later cutover; live
ExternalSecrets still use `onepassword`.
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md AGENTS.md
git commit -m "$(cat <<'EOF'
docs: note OpenBao Phase 1 secrets platform

Point AGENTS and CHANGELOG at the new OpenBao app while 1Password remains primary.
EOF
)"
```

---

### Task 7: Deploy + bootstrap verify

**Files:** none (cluster ops)

- [ ] **Step 1: Push `main`** so ApplicationSet creates Application `openbao`

```bash
git push origin main
```

- [ ] **Step 2: Wait for Argo sync**

```bash
kubectl get application openbao -n argocd
kubectl get pods,svc,ingressroute -n openbao
```

Expected: pod `openbao-0` Running (sealed/not initialized OK); IngressRoute present.

- [ ] **Step 3: Init + 1Password + unseal**

Follow ConfigMap runbook. Confirm:

```bash
kubectl exec -n openbao openbao-0 -- bao status
# Sealed: false, Initialized: true
```

Delete pod; wait ≤4m; status unsealed again without manual unseal.

- [ ] **Step 4: OIDC login**

Browser: `https://openbao.dominiksiejak.pl` → Authentik → admin into UI.

- [ ] **Step 5: Store readiness**

```bash
kubectl get clustersecretstore openbao
```

Expected: Ready=True after K8s auth bootstrap. If False, check store status message (auth role / sealed).

- [ ] **Step 6: Regression**

```bash
kubectl get clustersecretstore onepassword
kubectl get externalsecret -A | head
```

Expected: onepassword store healthy; no app ExternalSecret points at `openbao`.

---

## Spec coverage check

| Spec requirement | Task |
|------------------|------|
| OpenBao Helm + Kustomize ApplicationSet | 1 |
| Raft×1 local-path, critical, control-plane | 1 |
| Injector/CSI off | 1 |
| IngressRoute native-oidc + AdGuard | 2 |
| Shamir via 1P + unseal CronJob | 3 |
| ClusterSecretStore/openbao + eso-openbao SA | 4 |
| Authentik OIDC admins-only | 5 |
| Bootstrap runbook (KV, K8s auth, OIDC) | 4 |
| No ExternalSecret flips / 1P stays | 7 regression |
| CHANGELOG/AGENTS | 6 |
| Success criteria (OIDC, unseal after restart, store Ready) | 7 |

## Out of plan

- Secret migration / ExternalSecret cutover
- Raft snapshots to NAS
- GCP KMS
- HA 3-node
