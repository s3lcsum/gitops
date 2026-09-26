# Cloudflare Tunnel: k8s cloudflared only — design

**Date:** 2026-09-26
**Status:** approved

**Scope:** Remove the STRRL Cloudflare Tunnel Ingress Controller. Run a single `cloudflared` connector on lake Kubernetes. Tunnel origins stay Traefik-k8s so CrowdSec, Authentik, and other middlewares still apply. Retire the Portainer `stacks/cloudflared` connector.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Connector host | k8s only (`kubernetes/cloudflared`). Portainer stack gone. |
| Operator | Delete `kubernetes/cloudflare-tunnel-ingress-controller` (STRRL chart + `lake-k8s` tunnel creds). |
| Tunnel SoT | Remotely managed Lake/`homelab` tunnel via `terraform/cloudflare`. No in-cluster ingress ConfigMap. |
| Origin | Keep `https://traefik` in `var.tunnel_apps`. Pod `hostAliases` map `traefik` → `192.168.89.252` (Traefik-k8s). |
| Middlewares | Unchanged. Tunnel hits Traefik `websecure`; IngressRoutes keep CrowdSec / Authentik / headers. |
| Token | ExternalSecret → Secret `cloudflared` with `TUNNEL_TOKEN` (1Password). |
| Node pin | Prefer lake control-plane (toleration already present). Add explicit affinity / nodeSelector so hostAliases stay valid if workers join. |

## Context

Dual Cloudflare paths exist today:

1. **Lake tunnel** (`terraform/cloudflare`, name `homelab` / resource `Lake`) — remotely managed ingress. Active hosts (`n8n`, `auth`, `hass`) origin at `https://traefik` with Access JWT gate + `origin_server_name` = public hostname. Connectors: Portainer `stacks/cloudflared` (Docker `proxy` network → compose Traefik) and/or `kubernetes/cloudflared` (`hostAliases` → lake Traefik-k8s). Two connectors on one tunnel can reoriginate to **different** Traefiks depending on who answers — bad once edge moved to k8s.
2. **STRRL ingress controller** — Helm ApplicationSet child. Own tunnel name `lake-k8s`, IngressClass `cloudflare`. Would publish hosts by writing tunnel DNS/rules from Ingress objects and skip Traefik middlewares. No Ingress uses that class yet.

Existing public-host design (`docs/superpowers/specs/2026-08-21-cloudflare-tunnel-public-hosts-design.md`) already chose tunnel → Traefik → app. This work aligns connectors with Traefik-k8s and drops the bypass path.

## Goals

- One connector: Argo Application `cloudflared` on lake.
- Tunnel traffic always enters Traefik-k8s `:443`, then existing IngressRoutes / middlewares.
- Delete STRRL controller manifests and all gitops references (ApplicationSet ignoreDifferences, Kyverno label rules, README tree).
- Delete `stacks/cloudflared/` and stop the Portainer container on cutover.
- Document Edge paths as Traefik-k8s + k8s cloudflared + `terraform/cloudflare`.

## Non-goals

- Changing which hostnames sit in `var.tunnel_apps`.
- Editing Traefik middlewares or per-app IngressRoutes.
- Switching origins to raw `https://192.168.89.252` (hostAliases + `origin_server_name` stay).
- Local (ConfigMap) tunnel config that duplicates terraform.
- Terraform destroy of a dashboard-only `lake-k8s` tunnel (manual cleanup if it was created).
- Homepage / Gatus / blackbox probe redesign beyond fixing broken path strings.

## Architecture

```
Internet / CF Access
        │
        ▼
Cloudflare Tunnel edge (Lake / homelab)
        │  remotely managed ingress (terraform/cloudflare)
        ▼
cloudflared Deployment (ns cloudflared, lake node)
        │  TUNNEL_TOKEN from ExternalSecret
        │  resolves traefik → 192.168.89.252 (hostAliases)
        ▼
Traefik-k8s hostNetwork :443
        │  CrowdSec, Authentik forward-auth, secure-headers, …
        ▼
IngressRoute → Service → app
```

Catch-all unmatched hostnames remain `http_status:404` in the tunnel config.

## GitOps layout (after)

```
kubernetes/cloudflared/
  kustomization.yaml
  resources/
    namespace.yaml
    deployment.yaml          # existing; add node affinity if needed
    externalsecret.yaml      # new — TUNNEL_TOKEN

kubernetes/argocd/resources/application-cloudflared.yaml   # keep

# deleted
kubernetes/cloudflare-tunnel-ingress-controller/
stacks/cloudflared/
```

## Secrets

- Secret key: `TUNNEL_TOKEN` (same as `stacks/cloudflared/cloudflared.env.example`).
- 1Password: vault Servers, item `cloudflared` / field `credential` (or `password`), tag `ArgoCD External Secrets Operator`. Do not reuse STRRL item `cloudflare-tunnel-ingress/credential` (API token, not tunnel token).
- Token value: copy from Portainer `/opt/cloudflared/cloudflared.env` `TUNNEL_TOKEN=` (must match `cloudflare_zero_trust_tunnel_cloudflared.Lake`).
- ExternalSecret pattern matches other apps (`deletionPolicy: Retain`, `Prune=false` on target annotations).

## Cleanup checklist (git)

- Remove ApplicationSet `ignoreDifferences` block for Deployment `cloudflare-tunnel-ingress-controller`.
- Remove Kyverno mutate rules / ClusterRole references named for that controller in:
  - `add-recommended-labels.yaml`
  - `add-recommended-labels-existing.yaml`
  - `add-recommended-labels-rbac.yaml`
- README Edge table + tree: `stacks/cloudflared` → `kubernetes/cloudflared`; drop controller directory line.
- AGENTS.md already points at `kubernetes/cloudflared`; drop any controller mention if present.

## Cutover order

1. Ensure 1Password item + ExternalSecret sync; Secret `cloudflared` present; Deployment Ready on lake.
2. Confirm tunnel connector healthy in Cloudflare Zero Trust for Lake/`homelab`.
3. Spot-check a tunnel host (`auth` / `n8n` / `hass`) from outside LAN — Traefik middlewares still fire.
4. Stop and remove Portainer `cloudflared` container; delete `stacks/cloudflared` from git.
5. Delete STRRL Application (ApplicationSet drops it when `values.yaml` leaves main); prune namespace if left behind.
6. Optional: delete unused `lake-k8s` tunnel and 1Password API item in the dashboard.

## Verification

- `kubectl -n cloudflared get deploy,secret,externalsecret` — Ready, token present.
- Cloudflare Zero Trust → Tunnels → Lake: one healthy connector, no dependency on Portainer.
- External request to a `tunnel_apps` host hits Authentik/CrowdSec as on direct WAN (same IngressRoute path).
- `kubectl get ns cloudflare-tunnel-ingress-controller` absent (or empty after prune).
- No Portainer stack/container named `cloudflared`.

## Relation to prior design

Supersedes connector placement in `2026-08-21-cloudflare-tunnel-public-hosts-design.md` (Portainer + Docker `proxy`). Tunnel ingress rules, Access apps, and HTTPS-to-Traefik origin model from that doc remain in force; only the connector and the edge Traefik instance change to lake k8s.
