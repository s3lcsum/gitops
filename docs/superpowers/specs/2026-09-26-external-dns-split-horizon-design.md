# External-DNS split-horizon (Cloudflare + AdGuard) — design

**Date:** 2026-09-26
**Status:** approved (pending implementation plan)

**Scope:** Auto-create DNS for every Traefik `IngressRoute` `Host()` on lake: Cloudflare A → dynamic WAN IP (DNS-only); AdGuard dnsrewrite → `192.168.89.252`. Includes Portainer hop routes. Drop tofu tunnel CNAMEs for Traefik-backed hosts so external-dns owns those names.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Hostname source | Traefik `IngressRoute` (all under `kubernetes/**`, including Portainer hop `Host()` lists) |
| Compose-only hosts without a k8s hop | Out of scope v1 |
| Packaging | One Argo app `external-dns` (approach 1) |
| Dual providers | Two Deployments: Cloudflare + AdGuard webhook (`muhlba91/external-dns-provider-adguard`) |
| Traefik ↔ dual targets | IngressRoute → `DNSEndpoint` bridge (empty targets); not `--source=traefik-proxy` (that source requires a single `external-dns.kubernetes.io/target` and ignores `--default-targets`) |
| Cloudflare target | Dynamic WAN IP via in-cluster updater → ConfigMap → CF `--default-targets` |
| AdGuard target | Fixed `192.168.89.252` |
| Cloudflare proxy | DNS-only (grey cloud) so RouterOS allowlist sees real clients |
| Tunnel Traefik hosts (`n8n`, `auth`, `hass`) | Remove from `terraform/cloudflare` `tunnel_apps`; external-dns owns A records |
| Policy | `sync`, domain filter `dominiksiejak.pl`, distinct TXT owners |

## Goals

- New host on an IngressRoute → CF public A + AdGuard LAN rewrite without manual DNS edits.
- WAN IP changes → CF records update without git commit.
- LAN clients hitting AdGuard get `.252` (Traefik-k8s); public DNS points at WAN.
- Fit existing ApplicationSet child layout (`values.yaml` + `kustomization.yaml` + `resources/`).

## Non-goals

- Automating compose hosts that are **not** listed in Traefik-k8s IngressRoutes.
- Replacing cert-manager Cloudflare DNS-01 (separate token use; keep as-is).
- Orange-cloud / CF proxy in front of direct WAN Traefik.
- Migrating all AdGuard config into GitOps (only rewrite/dnsrewrite for managed hosts).
- Gateway API / Kubernetes Ingress as DNS sources.

## Problem

Traefik-k8s uses `IngressRoute` CRDs and `hostNetwork` (no LoadBalancer Service status). External-DNS Traefik source only emits endpoints when `external-dns.kubernetes.io/target` is set on the route; `--default-targets` does not apply. Split-horizon needs **two** targets for the same hostname, so a single annotation cannot drive both providers.

## Architecture

```
IngressRoute (cluster)
        │
        ▼
ingressroute-dnsendpoints (bridge)
        │  creates/updates externaldns.k8s.io/v1alpha1 DNSEndpoint
        │  (dnsName from Host(`…`), targets: [])
        │
        ├──────────────────────────┬─────────────────────────────┐
        ▼                          ▼                             ▼
wan-ip-updater              external-dns-cloudflare      external-dns-adguard
CronJob → ConfigMap         --source=crd                 --source=crd
wan-ip                      --provider=cloudflare        --provider=webhook
                            --default-targets=$WAN       --default-targets=192.168.89.252
                            txt-owner-id=k8s-cf          txt-owner-id=k8s-adguard
                            proxied=false                sidecar: adguard webhook
                                    │                             │
                                    ▼                             ▼
                            Cloudflare A (DNS-only)      AdGuard filtering
                            → WAN IP                     dnsrewrite → .252
```

### Why CRD bridge

| Approach | Verdict |
|----------|---------|
| `--source=traefik-proxy` + `--default-targets` | Broken upstream: empty endpoints dropped; flag unused |
| Annotate IngressRoute with one target | Cannot express WAN and `.252` at once |
| Two annotated route copies | Duplicates Traefik config; rejected |
| `DNSEndpoint` + dual `--source=crd` + per-instance `--default-targets` | Works; CRD source applies default targets when endpoint targets empty |

### Host parsing

Bridge watches `traefik.io` IngressRoutes cluster-wide. Extract hostnames from `spec.routes[].match` `Host(\`…\`)` (including `\|\|`-joined hop lists). Ignore non-`dominiksiejak.pl` if any. Delete `DNSEndpoint`s when Hosts disappear. Ownership labels: `app.kubernetes.io/managed-by=ingressroute-dnsendpoints`.

### WAN IP updater

- CronJob every 5m: `GET https://cloudflare.com/cdn-cgi/trace`, parse `ip=` line (IPv4 only; fail closed if missing/non-v4).
- Writes ConfigMap `wan-ip` key `ip` only when lookup succeeds (keep previous on failure; log error).
- CF Deployment reads target from that ConfigMap (env → args). On IP change: roll CF Deployment (pod-template checksum annotation or `kubectl rollout restart` from the Job). AdGuard Deployment unchanged.

### AdGuard webhook

- Image: `ghcr.io/muhlba91/external-dns-provider-adguard` (pin digest/tag at impl).
- Sidecar on AdGuard external-dns Pod (chart `provider.webhook`); listens localhost `:8888`.
- Env: `ADGUARD_URL`, `ADGUARD_USER`, `ADGUARD_PASSWORD` from ExternalSecret.
- `ADGUARD_URL`: `http://192.168.89.253:3000` (AdGuard on Portainer LXC host network).
- Provider writes Adblock-style filtering dnsrewrite rules (`|name^$dnsrewrite=NOERROR;A;192.168.89.252`), not classic `filtering.rewrites` YAML entries.
- Remove overlapping hosts from `stacks/adguard/conf/AdGuardHome.yaml.example` (and live conf after cutover) to avoid double management.

### Cloudflare

- ExternalSecret → same 1Password item as cert-manager (`cloudflare-dns` / `credential`) if token already has Zone DNS Edit on `dominiksiejak.pl`. If not, create scoped token + item; same ESO tag pattern (`ArgoCD External Secrets Operator`).
- Records: A, DNS-only (`--cloudflare-proxied=false`).
- `txt-owner-id: k8s-cf`; TXT prefix `_external-dns.` to avoid clashing with other zone TXT.

## GitOps layout

ApplicationSet discovers one Helm chart per `kubernetes/*/values.yaml`. Dual releases → Helm = Cloudflare; AdGuard + bridge + CronJob + secrets = kustomize `resources/`.

```
kubernetes/external-dns/
  values.yaml                    # chart pin: external-dns (CF instance)
  kustomization.yaml
  resources/
    externalsecret-cloudflare.yaml
    externalsecret-adguard.yaml
    wan-ip-cronjob.yaml          # + ServiceAccount/Role if needed
    ingressroute-dnsendpoints.yaml
    external-dns-adguard.yaml    # Deployment + RBAC + ServiceAccount (+ webhook)
```

| File | Notes |
|------|--------|
| `values.yaml` | `repoURL`/`chart`/`version`/`argoSync` + CF provider, `--source=crd`, domain filter, dry-run flag, CRD install, tolerations for control-plane |
| AdGuard manifests | Pin images; mirror chart defaults enough for lake (replicas 1). Optional later: Argo `kustomize.buildOptions: --enable-helm` + `helmCharts` if ApplicationSet template gains that |

Namespace: `external-dns` (dirname). RBAC: bridge needs list/watch IngressRoutes + CRUD DNSEndpoints; both external-dns need DNSEndpoint + related RBAC (chart for CF; copy for AdGuard).

### Secrets

| Secret | Source | Keys |
|--------|--------|------|
| Cloudflare API token | 1Password via ExternalSecret → ClusterSecretStore `onepassword` | token (same pattern as cert-manager) |
| AdGuard API | New 1Password item (Servers vault), tag for ESO | `url` (optional if hardcoded), `user`, `password` |

## Terraform / Cloudflare module changes

In `terraform/cloudflare/variables.tf` `tunnel_apps` defaults: set `n8n` / `auth` / `hass` origins to `""` (or remove keys) so tunnel CNAMEs + Zero Trust Access apps for those hosts are destroyed.

Keep tunnel resource for non-Traefik / future origins (`homeassistant-atom`, `dns`, empty placeholders).

**Cutover order**

1. Optional: CF external-dns `--dry-run` while CNAMEs still exist; confirm planned A set.
2. `tofu apply` in `terraform/cloudflare` → CNAMEs gone.
3. Disable dry-run → A records created.
4. Enable AdGuard external-dns; strip manual rewrites for synced hosts; verify LAN resolve → `.252`.

## Ops / failure modes

| Case | Behavior |
|------|----------|
| WAN lookup fails | Keep last ConfigMap IP; alert via pod/Job logs (no silent empty target) |
| AdGuard API down | AdGuard external-dns retries; LAN may serve stale rewrites until sync |
| Bridge down | No new Hosts; existing DNSEndpoints remain until pruned elsewhere |
| Accidental prune of unmanaged CF records | Domain filter + txt-owner-id; never use empty owner |
| Duplicate Host across routes | One DNSEndpoint per dnsName (bridge upsert by name); last-write wins |

Initial ship: both providers `dryRun: true` (or `--dry-run`) until log review, then flip in values/manifests.

## Verification

1. Deploy app → pods Ready; DNSEndpoint CRD present; bridge creates endpoints for `argocd`, `workflows`, `traefik-k8s`, hop hosts.
2. Dry-run logs list expected creates.
3. After tofu + live sync: `dig +short argocd.dominiksiejak.pl @1.1.1.1` → WAN; `@192.168.89.253` → `192.168.89.252`.
4. Add temporary Host on a test IngressRoute → both sides update; delete → both prune.
5. Force WAN ConfigMap change → CF record updates after roll.

## Out of scope follow-ups

- Compose-wide DNS without Traefik-k8s hops.
- Restoring CF Tunnel Access in front of selected hosts (would need opt-out annotation + tofu again).
- CoreDNS bypass of AdGuard for cluster pods (unchanged: still forward to AdGuard then 1.1.1.1).
