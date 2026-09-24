# Traefik-in-k8s edge — design

**Date:** 2026-09-24
**Status:** approved for planning (pending human review of this file)
**Scope:** Replace Cilium Gateway API L7 and Portainer Traefik with a single Traefik edge in Kubernetes.

## Context

Today’s edge is split:

| Path | Role |
|------|------|
| Portainer Traefik (`192.168.89.253`) | Compose stacks, CrowdSec, Authentik forward-auth, Docker labels |
| Cilium Gateway (`192.168.89.252`) | TLS terminate, HTTPRoutes to Traefik + LAN origins (nas/proxmox/hermes/router), argocd |

Cilium-as-proxy caused recurring pain: hostNetwork TPROXY / SYN_RECV, Gateway API defaulting vs Argo OutOfSync, secretsync copying Argo `tracking-id` onto `cilium-secrets`, BackendTLSPolicy ConfigMap-only CA, HTTPRoute hostname cap (16).

Cilium stays as **CNI only**. L7 moves to Traefik in-cluster.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Proxy | Traefik Helm via Argo CD |
| Placement | `hostNetwork` on node `192.168.89.252` (:80/:443) |
| Route source | Static GitOps IngressRoute / Middleware CRDs (no Docker provider) |
| Auth day-1 | Authentik forward-auth **and** CrowdSec bouncer |
| Workloads | Compose stays on Portainer; k8s keeps its Services |
| Out of scope v1 | Moving compose into k8s; changing Cloudflare Tunnel path; redesigning Authentik apps |

## Goals

- One L7 edge for LAN DNS `*.dominiksiejak.pl` → `.252`.
- Retire Portainer Traefik stack as router.
- Remove Cilium Gateway, HTTPRoutes, BackendTLSPolicies used for edge proxying.
- Preserve auth classification (`scripts/auth_classification.yaml`) and `make consistency` gates.
- Reuse existing wildcard TLS (`dominiksiejak-pl-tls` / cert-manager).

## Non-goals (v1)

- Replacing Cloudflare Tunnel + Access for the hosts that stay on that path.
- Migrating Docker workloads into Kubernetes.
- Moving CrowdSec LAPI into k8s (bouncer may call existing LAPI on `.253`).

## Architecture

```
Clients (LAN / WAN allowlist)
    → AdGuard rewrite *.dominiksiejak.pl → 192.168.89.252
    → Traefik (k8s, hostNetwork :80/:443)
         ├─ TLS: Secret dominiksiejak-pl-tls (cert-manager)
         ├─ Middleware chain from auth_classification
         │     CrowdSec bounce → Authentik forward-auth (when classed)
         └─ Backends
              ├─ in-cluster Service (e.g. argocd-server)
              └─ Service + EndpointSlice → 192.168.89.253 / LAN IPs
                    (compose hosts, nas, proxmox, hermes, router, …)
```

Cilium: kube-proxy replacement, NetworkPolicy, routing — **not** Gateway API for public HTTP.

## GitOps layout

Proposed tree (ApplicationSet discovers `kubernetes/traefik/values.yaml`):

```
kubernetes/traefik/
  values.yaml                 # chart pin + hostNetwork, entrypoints, providers
  kustomization.yaml
  resources/
    middlewares/              # authentik, crowdsec, headers, …
    routes/                   # IngressRoute per host or small groups
    backends/                 # Services + EndpointSlices for external IPs
```

### Traefik values (intent)

- Chart: official Traefik Helm (pin exact version in `values.yaml` like other apps).
- `hostNetwork: true`, entrypoints `web` :80 → redirect HTTPS, `websecure` :443.
- Provider: `kubernetesCRD` only (no Docker, no Kubernetes Ingress unless useful later).
- Toleration for control-plane taint (single-node lake).
- Publish neither NodePort nor LB VIP in v1.

### Middlewares

Port from `stacks/traefik` (file provider / labels) into Traefik CRDs:

- Authentik forward-auth (same outpost URL; Traefik must reach Authentik — typically `.253` or a dedicated Service/EndpointSlice).
- CrowdSec bouncer → existing LAPI on Portainer host (`.253`) unless LAPI is moved later.
- Security headers / other shared chains as today.

Map each host’s class in `scripts/auth_classification.yaml` to a middleware chain on its IngressRoute (`forward-auth` | `native-oidc` | `public` | `lan-only`).

### Routes

- One IngressRoute (or small grouped route) per hostname currently served by Traefik and/or Cilium HTTPRoutes.
- TLS: Traefik store / secret pointing at `dominiksiejak-pl-tls` (namespace strategy: copy or ExternalSecret / mirror into `traefik` ns — decide in plan; prefer single Secret in `traefik` ns via cert-manager Certificate or sync).
- No reliance on Docker labels after cutover; new compose services require a Git PR adding IngressRoute + backend EndpointSlice.

### Backends

For each non-k8s origin:

- `Service` (ClusterIP) + `EndpointSlice` with LAN IP and port (pattern already used under `kubernetes/cilium/resources/proxies/`).
- HTTPS origins: Traefik serversTransport / insecureSkipVerify or CA bundle as Traefik config — **not** Cilium BackendTLSPolicy.

## Cutover plan (phased)

1. **Bootstrap** — Deploy `kubernetes/traefik` on `.252` hostNetwork; prove HTTPS for `argocd` + one compose host (e.g. `homepage`) without flipping all DNS.
2. **Inventory** — Generate IngressRoutes + backends from current Traefik routers / compose labels + Cilium HTTPRoutes; align with `auth_classification.yaml`.
3. **Shadow** — Dual-run: Cilium Gateway and Portainer Traefik still authoritative for most hosts; Traefik-in-k8s serves test hostnames or temporary AdGuard overrides.
4. **Flip** — Point AdGuard static rewrites at `.252` (already the direction of the static list); confirm WAN allowlist still hits node IP.
5. **Drain** — Disable Portainer Traefik routers / remove stack; delete Cilium Gateway, HTTPRoutes, BackendTLSPolicies, related CA ConfigMaps used only for Gateway.
6. **Verify** — `make consistency`; blackbox / gatus; smoke Authentik and CrowdSec on a forward-auth and a public host.

Rollback: re-enable Portainer Traefik + AdGuard → `.253` (or restore Cilium Gateway manifests from git history).

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| hostNetwork + Cilium eBPF steals :443 (SYN_RECV) | Keep `bpf.tproxy: false`; validate handshake on Traefik before DNS flip; avoid privileged iptables strip DaemonSets |
| CrowdSec bouncer cannot reach LAPI on `.253` | Explicit EndpointSlice/network allow; optional later move LAPI into k8s |
| Route drift vs Docker labels | Consistency check extended to IngressRoutes (or host list derived from `routes/`); PR checklist for new stacks |
| Wildcard cert namespace | Certificate or secret mirror into Traefik namespace before flip |
| Dual WAN / CF Tunnel confusion | Document: direct WAN still hits `.252` Traefik; Tunnel path unchanged |

## Success criteria

- [ ] All classified Traefik/Cilium HTTP hosts served by Traefik-in-k8s on `.252`.
- [ ] Portainer Traefik not in the request path.
- [ ] No Cilium Gateway / HTTPRoute / BackendTLSPolicy required for edge HTTP.
- [ ] Authentik forward-auth and CrowdSec enforce on day-1 for classified hosts.
- [ ] `make consistency` green; argocd and representative compose UIs healthy over HTTPS.

## Open points for implementation plan

- Exact Traefik Helm chart version and values schema.
- Certificate placement (`cilium` ns vs `traefik` ns).
- Whether CrowdSec bouncer runs as Traefik plugin, sidecar, or separate Deployment.
- Automation to draft IngressRoutes from existing compose labels (one-shot script vs manual).
- README / AGENTS.md updates for “edge = Traefik-in-k8s”.

## References

- Current Cilium edge: `kubernetes/cilium/resources/`
- Current Traefik compose: `stacks/traefik/`
- Auth classes: `scripts/auth_classification.yaml`
- Argo ApplicationSet: `kubernetes/argocd/resources/applicationset.yaml`
