# Cloudflare Tunnel k8s-only Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One lake `cloudflared` connector; delete STRRL tunnel ingress operator and Portainer `stacks/cloudflared`.

**Architecture:** Keep remotely managed Lake tunnel in `terraform/cloudflare` (origins `https://traefik`). Add ExternalSecret for `TUNNEL_TOKEN`. Delete operator + compose stack + stale Kyverno/ApplicationSet refs. No Traefik or `tunnel_apps` changes.

**Tech Stack:** Kubernetes Deployment, External Secrets Operator, Argo CD, OpenTofu Cloudflare (unchanged).

**Spec:** `docs/superpowers/specs/2026-09-26-cloudflared-k8s-only-design.md`

## Global Constraints

- Do not add nodeSelector / affinity. Existing control-plane toleration + `hostAliases` is enough.
- Do not change `terraform/cloudflare` `tunnel_apps` or tunnel config.
- Do not edit Traefik middlewares or IngressRoutes.
- Image stays `cloudflare/cloudflared:2026.9.1`.
- Secret key `TUNNEL_TOKEN`. 1Password item `cloudflared` / field `credential`, vault Servers, tag `ArgoCD External Secrets Operator`.
- No secret values in git.
- YAGNI: no local tunnel ConfigMap, no second tunnel, no IngressClass.

## File map

| Path | Action |
|------|--------|
| `kubernetes/cloudflared/resources/externalsecret.yaml` | Create |
| `kubernetes/cloudflared/kustomization.yaml` | List ExternalSecret |
| `kubernetes/cloudflare-tunnel-ingress-controller/` | Delete whole dir |
| `kubernetes/argocd/resources/applicationset.yaml` | Drop ignoreDifferences for STRRL Deployment |
| `kubernetes/kyverno/resources/add-recommended-labels.yaml` | Drop `cloudflare-tunnel-controller` rule |
| `kubernetes/kyverno/resources/add-recommended-labels-existing.yaml` | Same |
| `kubernetes/kyverno/resources/add-recommended-labels-rbac.yaml` | Drop Deployment `cloudflare-tunnel-ingress-controller` rule |
| `stacks/cloudflared/` | Delete whole dir |
| `README.md` | Edge paths + tree |

## Prerequisites (human)

1. Create 1Password item `cloudflared` with field `credential` = current `TUNNEL_TOKEN` from Portainer `/opt/cloudflared/cloudflared.env`. Tag `ArgoCD External Secrets Operator`.
2. After git lands and Argo syncs Secret + Ready Deployment: stop Portainer container `cloudflared` (`docker stop cloudflared && docker rm cloudflared` on portainer host).
3. Optional later: delete unused Cloudflare tunnel `lake-k8s` and 1Password item `cloudflare-tunnel-ingress` in the dashboard.

---

### Task 1: ExternalSecret for TUNNEL_TOKEN

**Files:**
- Create: `kubernetes/cloudflared/resources/externalsecret.yaml`
- Modify: `kubernetes/cloudflared/kustomization.yaml`

- [ ] **Step 1: Write ExternalSecret**

```yaml
# 1Password vault Servers. Tag: ArgoCD External Secrets Operator
# Item: cloudflared / credential  (TUNNEL_TOKEN for Lake/homelab tunnel)
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: cloudflared
  namespace: cloudflared
  labels:
    app.kubernetes.io/name: cloudflared
    app.kubernetes.io/instance: cloudflared
    app.kubernetes.io/part-of: cloudflared
    app.kubernetes.io/managed-by: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: onepassword
    kind: ClusterSecretStore
  target:
    name: cloudflared
    creationPolicy: Owner
    deletionPolicy: Retain
    template:
      engineVersion: v2
      metadata:
        labels: {}
        annotations:
          argocd.argoproj.io/sync-options: Prune=false
      data:
        TUNNEL_TOKEN: "{{ .token }}"
  data:
    - secretKey: token
      remoteRef:
        key: cloudflared/credential
```

- [ ] **Step 2: List it in kustomization**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: cloudflared
resources:
  - resources/namespace.yaml
  - resources/externalsecret.yaml
  - resources/deployment.yaml
```

- [ ] **Step 3: Commit**

```bash
git add kubernetes/cloudflared/resources/externalsecret.yaml kubernetes/cloudflared/kustomization.yaml
git commit -m "$(cat <<'EOF'
feat(cloudflared): pull TUNNEL_TOKEN from 1Password

EOF
)"
```

---

### Task 2: Delete STRRL operator + leftovers

**Files:**
- Delete: `kubernetes/cloudflare-tunnel-ingress-controller/` (all files)
- Modify: `kubernetes/argocd/resources/applicationset.yaml` — remove the second `ignoreDifferences` entry (Deployment `cloudflare-tunnel-ingress-controller`)
- Modify: Kyverno files listed in file map — remove every rule / RBAC entry that names that controller

- [ ] **Step 1: Delete the operator directory**

```bash
rm -rf kubernetes/cloudflare-tunnel-ingress-controller
```

- [ ] **Step 2: ApplicationSet — leave only flannel ignoreDifferences**

`ignoreDifferences` should be only the `kube-flannel-ds` DaemonSet block. Remove the entire `- group: apps` / `kind: Deployment` / `name: cloudflare-tunnel-ingress-controller` entry.

- [ ] **Step 3: Kyverno — drop controller rules**

In `add-recommended-labels.yaml` and `add-recommended-labels-existing.yaml`, delete the whole `- name: cloudflare-tunnel-controller` rule (match + mutate).

In `add-recommended-labels-rbac.yaml`, delete the ClusterRole rule whose `resourceNames` is only `cloudflare-tunnel-ingress-controller`.

- [ ] **Step 4: Commit**

```bash
git add -A kubernetes/cloudflare-tunnel-ingress-controller \
  kubernetes/argocd/resources/applicationset.yaml \
  kubernetes/kyverno/resources/add-recommended-labels.yaml \
  kubernetes/kyverno/resources/add-recommended-labels-existing.yaml \
  kubernetes/kyverno/resources/add-recommended-labels-rbac.yaml
git commit -m "$(cat <<'EOF'
chore(k8s): remove cloudflare-tunnel-ingress-controller

EOF
)"
```

---

### Task 3: Drop Portainer stack + fix README

**Files:**
- Delete: `stacks/cloudflared/` (compose + env example)
- Modify: `README.md` Edge table + tree

- [ ] **Step 1: Delete compose stack**

```bash
rm -rf stacks/cloudflared
```

(`terraform/portainer/locals.tf` has no `cloudflared` entry — nothing to change there.)

- [ ] **Step 2: README paths**

Edge row paths: `kubernetes/traefik/`, `stacks/traefik/`, `kubernetes/cloudflared/`, `terraform/cloudflare/`.

Tree: keep `cloudflared/` under `kubernetes/`; remove `cloudflare-tunnel-ingress-controller/` line.

- [ ] **Step 3: Commit**

```bash
git add -A stacks/cloudflared README.md
git commit -m "$(cat <<'EOF'
chore: retire Portainer cloudflared; doc k8s connector

EOF
)"
```

---

### Task 4: Cutover check (after push / Argo sync)

No more git. Run after 1Password item exists and Tasks 1–3 are on `main`.

- [ ] **Step 1: Secret + pod**

```bash
kubectl -n cloudflared get externalsecret,secret,deploy,pods
```

Expected: ExternalSecret Ready, Secret `cloudflared` present, Deployment Available, pod Running.

- [ ] **Step 2: Spot-check tunnel host**

From outside LAN, hit one of `n8n` / `auth` / `hass`. Expect same Traefik middleware behavior as direct WAN (Authentik / CrowdSec as configured).

- [ ] **Step 3: Stop Portainer connector**

```bash
ssh portainer 'docker stop cloudflared && docker rm cloudflared'
```

Expected: Cloudflare Zero Trust still shows one healthy Lake/`homelab` connector (the k8s pod).

- [ ] **Step 4: Confirm operator gone**

```bash
kubectl get ns cloudflare-tunnel-ingress-controller
```

Expected: NotFound (or empty after ApplicationSet prune).
