# Cilium CNI-only + Traefik-k8s ingress — design

**Date:** 2026-09-24
**Status:** implementing (GitOps landed; cutover requires draining live Cilium Gateway before Traefik hostNetwork binds)
**Supersedes:** `docs/superpowers/specs/2026-09-24-traefik-k8s-edge-design.md` (retire Portainer Traefik as edge). Portainer Traefik **stays** as Docker origin proxy.

## Context

Edge today is tangled:

| Piece | Current role |
|-------|----------------|
| Cilium Gateway (`192.168.89.252`) | TLS terminate, HTTPRoutes (argocd, traefik-k8s dashboard, LAN proxies) |
| Traefik-k8s (`traefik` ns, ClusterIP) | Pilot IngressRoutes (argocd, homepage) + middlewares; not yet on `:80/:443` |
| Portainer Traefik (`192.168.89.253`) | Compose stacks, CrowdSec, Authentik, Docker labels |

Cilium-as-L7 caused recurring pain (TPROXY/SYN_RECV, Gateway defaulting vs Argo, secretsync tracking-id, BackendTLSPolicy limits). Goal: **clean separation**.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Cilium | CNI + kube-proxy replacement only — no Gateway API edge |
| Ingress | Traefik Helm in `traefik` namespace, eventual `hostNetwork` on `.252` |
| argocd | Traefik `IngressRoute` → in-cluster `argocd-server` (not HTTPRoute) |
| Compose path | Explicit allowlist of hosts → HTTPS hop to Portainer Traefik `.253:443` |
| Catch-all | No — missing host = 404 |
| TLS + auth | Traefik-k8s terminates TLS; CrowdSec + Authentik per `auth_classification` |
| Portainer Traefik | Dumb origin: Docker-label backends; Authentik/CrowdSec stripped for allowlisted hosts |
| Inter-proxy TLS | HTTPS to `.253:443` + `ServersTransport` `insecureSkipVerify` |
| Dashboard | `traefik-k8s.dominiksiejak.pl` via IngressRoute (Authentik-gated) |

## Goals

- Cilium namespace = CNI only (`gatewayAPI.enabled: false`; no edge Gateway/HTTPRoute/BackendTLSPolicy).
- Traefik namespace = sole L7 ingress for LAN DNS `*.dominiksiejak.pl` → `.252`.
- `argocd.dominiksiejak.pl` served by IngressRoute to in-cluster Service.
- Allowlisted compose hosts: Traefik-k8s → Portainer Traefik → container.
- `traefik-k8s.dominiksiejak.pl` shows Traefik dashboard.
- Preserve `scripts/auth_classification.yaml` and `make consistency` gates.

## Non-goals (v1)

- Catch-all proxy to Portainer Traefik.
- Migrating compose workloads into Kubernetes.
- Changing Cloudflare Tunnel + Access path.
- Moving CrowdSec LAPI into k8s.
- Retiring Portainer Traefik entirely (old edge design).

## Architecture

```
Clients (LAN / WAN allowlist)
    → AdGuard rewrite *.dominiksiejak.pl → 192.168.89.252
    → Traefik-k8s (hostNetwork :80 → redirect HTTPS, :443)
         ├─ TLS: Secret dominiksiejak-pl-tls (cert-manager, traefik ns)
         ├─ Middleware: CrowdSec → Authentik (when classed)
         └─ Backends
              ├─ argocd → Service argocd-server:80 (argocd ns)
              ├─ traefik-k8s → dashboard (entryPoint traefik / api@internal)
              └─ allowlist Host() → Service + EndpointSlice → 192.168.89.253:443
                    ServersTransport: insecureSkipVerify
                    → Portainer Traefik (no edge auth middlewares)
                    → compose containers via Docker labels
```

Cilium: pod networking, NetworkPolicy, kube-proxy replacement — **not** public HTTP.

## GitOps layout

```
kubernetes/traefik/
  values.yaml                 # chart pin; hostNetwork after cutover; kubernetesCRD; CrowdSec plugin
  kustomization.yaml
  resources/
    certificate.yaml          # wildcard → dominiksiejak-pl-tls in traefik ns
    externalsecret-crowdsec.yaml
    middlewares/              # authentik, crowdsec, secure-headers, lan-only
    backends/
      portainer-traefik.yaml  # Service + EndpointSlice → .253:443
    servers-transports.yaml   # insecureSkipVerify for Portainer hop
    routes/
      argocd.yaml
      dashboard.yaml          # Host(traefik-k8s.dominiksiejak.pl)
      <host>.yaml             # one IngressRoute per allowlisted compose host

kubernetes/cilium/
  values.yaml                 # gatewayAPI.enabled: false; drop Envoy-for-Gateway if unused
  kustomization.yaml          # only non-edge resources (or empty extras)
  # DELETE: resources/edge.yaml, resources/proxies/*

kubernetes/argocd/resources/
  # DELETE: httproute.yaml (and kustomization entry)
  # Drop Gateway/HTTPRoute ignoreDifferences when unused
```

### Allowlist rule

- Compose host that should stay on Portainer path → PR adds `routes/<host>.yaml` pointing at the shared `portainer-traefik` backend + `auth_classification` entry.
- No default backend for unmatched hosts.
- Pilot routes that currently hit compose via a dedicated EndpointSlice (e.g. `homepage`) convert to the Portainer hop — no parallel direct-to-container backends for allowlisted hosts.
- In-cluster Services only for true k8s apps (argocd, dashboard).
- Consistency check should treat Traefik-k8s IngressRoutes (plus intentional exceptions) as edge source of truth after cutover.

### Portainer Traefik

- Keep stack for Docker service discovery and container routing.
- Remove Authentik forward-auth and CrowdSec bouncer from routers for allowlisted hosts (or globally once Traefik-k8s owns auth) so users are not challenged twice.
- TLS on `.253:443` may remain (k8s hop uses skip-verify); no requirement to add a cleartext-only entrypoint in v1.

## Cutover

1. **Prepare (ClusterIP):** Finish IngressRoutes, middlewares, Portainer backend, serversTransport. Cilium Gateway still owns live `:80/:443`.
2. **Auth strip on Portainer:** Disable edge auth middlewares for hosts about to flip (avoid double auth on cutover).
3. **Port flip:** Delete/scale down Cilium Gateway (+ HTTPRoutes) → set Traefik `hostNetwork: true` → bind `:80/:443`.
4. **Verify DNS:** AdGuard `*.dominiksiejak.pl` → `.252`. Smoke argocd, dashboard, 1–2 allowlisted compose hosts.
5. **Drain Cilium L7:** `gatewayAPI: false`; remove `edge.yaml` / `proxies/*`; stop issuing wildcard cert into `cilium` ns.
6. **Consistency:** `make consistency`; blackbox/gatus; Authentik + CrowdSec on a forward-auth host and a public host.

**Rollback:** Restore Cilium Gateway manifests from git; set Traefik `hostNetwork: false`; re-enable Portainer auth if stripped.

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| hostNetwork + Cilium eBPF steals `:443` (SYN_RECV) | Keep `bpf.tproxy: false`; Gateway must be down before Traefik binds; smoke TLS handshake before relying on DNS |
| Double auth | Strip Portainer Authentik/CrowdSec for allowlisted hosts before cutover |
| Host missing from allowlist | Fail closed (404); extend consistency to require IngressRoute for hosts that should hit the k8s edge |
| Skip-verify LAN hop | Trusted LAN only; document; optional later CA-pinned `ServersTransport` |
| Wildcard cert namespace | Certificate (or mirror) in `traefik` ns before flip |
| Drift vs old “retire Portainer” plan | This spec supersedes; update AGENTS.md/README when implementing |

## Success criteria

- [ ] Cilium: no Gateway / HTTPRoute / BackendTLSPolicy required for edge HTTP
- [ ] `argocd.dominiksiejak.pl` via Traefik IngressRoute → in-cluster Service
- [ ] `traefik-k8s.dominiksiejak.pl` dashboard behind Authentik
- [ ] Allowlisted compose hosts: Traefik-k8s TLS+auth → HTTPS `.253` → Portainer Traefik → container
- [ ] Non-allowlisted host does not accidentally proxy
- [ ] `make consistency` green; `auth_classification.yaml` still source of truth for middleware chains

## Open points for implementation plan

- Exact initial allowlist (which compose hosts in v1 PRs).
- Whether dashboard uses chart `ingressRoute.dashboard` or a hand-written IngressRoute only.
- Consistency-script changes for IngressRoute-as-edge inventory.
- AGENTS.md / README wording: edge = Traefik-k8s; Portainer Traefik = origin only.
- Mark old edge plan/spec as superseded in-tree.

## References

- Prior (superseded) design: `docs/superpowers/specs/2026-09-24-traefik-k8s-edge-design.md`
- Prior plan: `docs/superpowers/plans/2026-09-24-traefik-k8s-edge.md`
- Cilium: `kubernetes/cilium/`
- Traefik-k8s: `kubernetes/traefik/`
- Portainer Traefik: `stacks/traefik/`
- Auth classes: `scripts/auth_classification.yaml`
