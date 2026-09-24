# Cilium CNI + Traefik-k8s ingress — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Cilium CNI-only; Traefik-k8s the L7 edge on `.252` with IngressRoutes; allowlisted compose hosts HTTPS-hop to Portainer Traefik; argocd + `traefik-k8s` dashboard in-cluster.

**Architecture:** Traefik Helm (`traefik` ns) terminates TLS/auth. Shared `portainer-traefik` Service+EndpointSlice → `192.168.89.253:443` with `ServersTransport` insecureSkipVerify. Auth class → middleware chain on IngressRoutes. Cilium drops Gateway API. Portainer Traefik drops edge CrowdSec/Authentik (origin only).

**Tech Stack:** Traefik Helm 41.6.0, Traefik CRDs, cert-manager, Cilium 1.20.2, Portainer compose Traefik.

**Spec:** `docs/superpowers/specs/2026-09-24-cilium-cni-traefik-ingress-design.md`

## Global Constraints

- No catch-all; explicit allowlist hosts only.
- argocd = IngressRoute (not HTTPRoute).
- Inter-proxy: HTTPS `.253:443` + insecureSkipVerify.
- `bpf.tproxy: false` stays on Cilium.
- Prune off on Argo apps — removing manifests orphans live objects until manual delete.
- **Cutover:** Gateway must release `:80/:443` before Traefik `hostNetwork: true` binds. Pause Argo sync or sequence manually if needed.

## File map

| Path | Responsibility |
|------|----------------|
| `scripts/auth_classification.yaml` | Restore + update for k8s edge hosts |
| `kubernetes/traefik/resources/backends/portainer-traefik.yaml` | Service + EndpointSlice → `.253:443` |
| `kubernetes/traefik/resources/servers-transports.yaml` | insecureSkipVerify |
| `kubernetes/traefik/resources/routes/*.yaml` | IngressRoutes by auth class + argocd + dashboard |
| `kubernetes/traefik/resources/httproute.yaml` | DELETE (Cilium-parented dashboard) |
| `kubernetes/traefik/values.yaml` | hostNetwork, dashboard IngressRoute |
| `kubernetes/traefik/kustomization.yaml` | Resource list |
| `kubernetes/cilium/values.yaml` | `gatewayAPI.enabled: false` |
| `kubernetes/cilium/resources/edge.yaml` | DELETE |
| `kubernetes/cilium/kustomization.yaml` | Empty / drop edge |
| `kubernetes/argocd/resources/httproute.yaml` | DELETE |
| `kubernetes/cert-manager/resources/certificate.yaml` | Stop issuing into `cilium` ns |
| `stacks/traefik/traefik.yaml` | Strip entrypoint CrowdSec/secure-headers |
| `stacks/*/compose.yaml` | Strip `authentik@docker` edge middlewares |

---

### Task 1: Restore auth classification + Portainer backend transport

**Files:**
- Create: `scripts/auth_classification.yaml`
- Create: `kubernetes/traefik/resources/backends/portainer-traefik.yaml`
- Create: `kubernetes/traefik/resources/servers-transports.yaml`
- Delete: `kubernetes/traefik/resources/backends/homepage.yaml`

- [ ] **Step 1:** Restore classification from pre-delete content; add `argocd` + `traefik-k8s`; drop gone stacks (`phase`, `vault`, `vaultwarden` if absent); keep allowlist hosts from former Cilium `traefik`/`traefik-1`/`traefik-2` HTTPRoutes + nas/proxmox/router/hermes.

- [ ] **Step 2:** Add `portainer-traefik` Service+EndpointSlice (port 443) and `ServersTransport` `portainer-insecure`.

- [ ] **Step 3:** Remove dedicated homepage EndpointSlice backend (homepage uses Portainer hop).

---

### Task 2: IngressRoutes (argocd, dashboard, allowlist by class)

**Files:**
- Modify: `kubernetes/traefik/resources/routes/argocd.yaml`
- Create: `kubernetes/traefik/resources/routes/dashboard.yaml`
- Create: `kubernetes/traefik/resources/routes/portainer-forward-auth.yaml`
- Create: `kubernetes/traefik/resources/routes/portainer-native-oidc.yaml`
- Create: `kubernetes/traefik/resources/routes/portainer-public.yaml`
- Create: `kubernetes/traefik/resources/routes/portainer-lan-only.yaml`
- Delete: `kubernetes/traefik/resources/routes/homepage.yaml`
- Delete: `kubernetes/traefik/resources/httproute.yaml`
- Modify: `kubernetes/traefik/kustomization.yaml`
- Modify: `kubernetes/traefik/values.yaml` (dashboard via route file; disable chart dashboard route or align)

Middleware map:
- forward-auth → crowdsec-bouncer, secure-headers, authentik
- native-oidc → crowdsec-bouncer, secure-headers
- public → crowdsec-bouncer, secure-headers
- lan-only → crowdsec-bouncer, secure-headers, lan-only

Portainer hop service block:
```yaml
services:
  - name: portainer-traefik
    port: 443
    scheme: https
    serversTransport: portainer-insecure
```

- [ ] **Step 1:** Write class-grouped IngressRoutes with `Host(`x`) || Host(`y`)` matches for every allowlisted host.
- [ ] **Step 2:** Dashboard IngressRoute `Host(`traefik-k8s.dominiksiejak.pl`)` → `api@internal` or service port 8080 + authentik.
- [ ] **Step 3:** Update kustomization; remove Cilium HTTPRoute for dashboard.

---

### Task 3: Drain Cilium L7 + ArgoCD HTTPRoute

**Files:**
- Modify: `kubernetes/cilium/values.yaml`
- Delete: `kubernetes/cilium/resources/edge.yaml`
- Modify: `kubernetes/cilium/kustomization.yaml`
- Delete: `kubernetes/argocd/resources/httproute.yaml`
- Modify: `kubernetes/argocd/resources/kustomization.yaml`
- Modify: `kubernetes/argocd/resources/application.yaml` (drop Gateway/HTTPRoute ignoreDifferences if unused)
- Modify: `kubernetes/cert-manager/resources/certificate.yaml` or kustomization — remove cilium-ns Certificate

- [ ] **Step 1:** `gatewayAPI.enabled: false`; drop edge from kustomization (delete file).
- [ ] **Step 2:** Remove argocd HTTPRoute from GitOps.
- [ ] **Step 3:** Remove/retarget cilium Certificate.

---

### Task 4: Traefik hostNetwork + Portainer auth strip

**Files:**
- Modify: `kubernetes/traefik/values.yaml` → `hostNetwork: true`, `dnsPolicy: ClusterFirstWithHostNet`
- Modify: `stacks/traefik/traefik.yaml` — remove entrypoint `crowdsec-bouncer@file` + `secure-headers@file`
- Modify: compose stacks — remove `authentik@docker` middleware labels (auth now on k8s)

- [ ] **Step 1:** Enable hostNetwork on Traefik values.
- [ ] **Step 2:** Strip Portainer edge auth middlewares.
- [ ] **Step 3:** Document cutover: delete live Gateway/HTTPRoutes (prune off), then ensure Traefik pod binds `:443`.

---

### Task 5: Docs touch

**Files:**
- Modify: `AGENTS.md` edge wording (brief)
- Mark design status approved/implemented-in-progress

- [ ] **Step 1:** AGENTS: Cilium CNI-only; edge = Traefik-k8s; Portainer Traefik = origin.
- [ ] **Step 2:** Spec status → implementing.

## Cutover checklist (human / cluster)

1. Pause Argo auto-sync on `cilium` + `traefik` if both would race.
2. Sync Traefik resources (CRDs/routes) while still ClusterIP **or** sync everything after Gateway down.
3. Delete live `Gateway/cilium` + HTTPRoutes (Git no longer manages; prune off).
4. Sync Traefik with hostNetwork; confirm `ss -lntp | grep -E ':80|:443'` is Traefik.
5. Smoke: argocd, traefik-k8s, homepage, one forward-auth host.
6. `make apply` portainer after compose/traefik.yaml auth strip.
7. Resume auto-sync.

## Spec coverage

| Spec item | Task |
|-----------|------|
| Cilium CNI only | 3 |
| Traefik ingress hostNetwork | 4 |
| argocd IngressRoute | 2 |
| Allowlist → Portainer HTTPS | 1–2 |
| TLS+auth on k8s | 2, 4 |
| traefik-k8s dashboard | 2 |
| Portainer dumb origin | 4 |
| auth_classification | 1 |
