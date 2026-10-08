# AGENTS.md — Home Infrastructure as Code

Public repo. LAN topology and hostnames are intentional. Do not privatize them. Never commit `*.env`, `*.tfvars`, `.mcp.json`, or `.opencode/opencode.json` / `.opencode/kubeconfig-k8s-lake`.

## Commands

- OpenTofu, not Terraform. Pin: `1.12.5` (`terraform/.opentofu-version`). Each module `Makefile` includes `terraform/base.Makefile`.
- Plan/apply ownership: **Terrakube** org `HomeLab` (UI apply; VCS plan on PR). One workspace per `terraform/<module>` dir. Remote backend hostname `terrakube-api.dominiksiejak.pl`.
- Local CLI: `tofu login terrakube-api.dominiksiejak.pl` (or Terrakube PAT in `~/.terraform.d/credentials.tfrc.json`). From `terraform/<module>/`: `make check` then remote `tofu plan` / UI apply. Extra flags: `TOFU_ARGS`.
- `required_version = ">= 1.11.5"`. Pin providers to exact versions, never `~>`.
- Workspace secrets live in Terrakube vars (sourced from local `defaults.auto.tfvars` / 1Password). Do not commit `*.tfvars`.
- `terraform/portainer` is gone. `terraform/postgres` targeted compose Postgres on the Portainer LXC at `192.168.89.253`. That host is down. Do not plan or apply `terraform/postgres`. Do not SSH to `portainer`. Do not recreate the portainer module. Leave its GCS backend alone.
- `terraform/gcp`: `make state-rm-legacy` drops retired resources from state (includes Vault KMS). Does not delete them in GCP. Executor needs GCP credentials as workspace ENV.
- `terraform/cloudflare`: `make show-token` prints the tunnel token.
- Retired: `.github/workflows/terraform.yml` (GHA WireGuard tofu). Do not resurrect it.
- Pre-commit: `tofu_fmt`, `tofu_validate`, `terraform_tflint`. YAML hook skips `kubernetes/*/templates|charts|resources`.

Root `Makefile` only has `help`. Do not add `serve` / `build` / `lint` / `test` / `consistency` back until `mkdocs.yml` and `scripts/check-consistency.py` exist.

## Layout

- `kubernetes/` is the workload tree. `terraform/` is OpenTofu (Authentik apps, AdGuard rewrites, RouterOS, UniFi WLAN, Cloudflare, Grafana Cloud, NetBox objects, GCP, compose Postgres users).
- Two Argo patterns. Do not mix them.
  - Helm ApplicationSet (`kubernetes/argocd/resources/applicationset.yaml`): a dir with `values.yaml` whose top keys are `repoURL` / `chart` / `version`. `argocd` is excluded. Auto-sync, selfHeal, prune. `cert-manager` schema rejects those pin keys — the Application sets `skipSchemaValidation: true`. Do not remove it.
  - Kustomize-only apps have no `values.yaml`, so they are not in the ApplicationSet. Each is `kubernetes/argocd/resources/application-<name>.yaml`, and that file must be listed in `resources/kustomization.yaml`. Missing either → Argo never creates the Application.
- ApplicationSet merge: `kustomization.yaml` beside `values.yaml` adds a third source (Kustomize path `kubernetes/<app>`). Absent file → that source is dropped. A `kustomization.yaml` whose `kind` is not `Kustomization` will not keep the directory source.
- Flannel chart cannot emit pod labels. Kyverno injects them. `applicationset.yaml` `ignoreDifferences` on `kube-flannel-ds` stops selfHeal from stripping them and rolling pods. Do not delete those jsonPointers.
- PriorityClasses live in `kubernetes/kyverno/resources/priorityclasses.yaml`: `homelab-critical` (1000000), `homelab-high` (100000), `homelab-low` (-100, `preemptionPolicy: Never`). Unset stays at the cluster default (0) and outranks `homelab-low` — always set an explicit class. Do not mark `homelab-critical` `globalDefault`. Dep rule: depended-upon outranks dependent. Shared Postgres + AdGuard are `homelab-critical` (CoreDNS / Authentik / external-dns consumers sit at or below). MQTT `homelab-high` → Zigbee2MQTT/HA `homelab-low`. Authentik server `homelab-high` → outposts `homelab-low`. Redis/minio deps outrank their app pods.
- Kyverno resource webhooks must stay `failurePolicy: Ignore`. `features.forceFailurePolicyIgnore` covers the window while the admission controller is up. `resources/webhook-failure-policy.yaml` is what Argo puts back when it is down — the controller rewrites those objects to `Fail` while running, and selfHeal races it back. Do not delete that overlay. Do not set `Replace` on those webhook configs.
- Argo CD self Application (`resources/application.yaml`) ignores `argocd-secret` `.data` because ESO merges the OIDC client secret. Empty `group:` on that ignore is dropped by the API and never converges — leave group unset.
- Bootstrap (only when Argo is down): `make -C kubernetes/argocd bootstrap`. Context `k8s@lake`, chart `argo-cd` `10.9.6`.

Kustomize-only (no `values.yaml`): adguard, authentik, calibre, cloudflared, coredns, external-dns, gitea, grafana-synthetic-agent, hass, homepage, mediabox, monitoring, n8n, netbox, unifi, watchyourlan, wealthfolio. Gatus is gone. Do not add `application-gatus.yaml` back unless `kubernetes/gatus` exists.

## Scheduling and edge

- `k8s` is the only control plane and the preferred node. Kyverno `worker-overflow-taint` puts `homelab.dominiksiejak.pl/worker=true:PreferNoSchedule` on every other node. PreferNoSchedule is a score penalty, not a filter.
- Traefik-k8s is a hostNetwork DaemonSet (`:80/:443` on every node). Public WAN arrives at `192.168.89.252`. Per-app IngressRoutes live in `kubernetes/<app>/resources/` in that app's namespace. Middleware refs need `namespace: traefik`. TLS comes from the Traefik default `TLSStore`.
- Three ingress paths. Do not collapse them. WAN is firewalled (`allowed-wan` → Traefik-k8s on `.252`). WireGuard (`vpn.dominiksiejak.pl:51820`, overlay `192.168.200.0/24`) lands peers on the LAN. Cloudflare Tunnel + Access is a separate WAF path, not a substitute for either.
- Auth class per host: `scripts/auth_classification.yaml` (`forward-auth` | `native-oidc` | `public` | `lan-only`). The checker that failed on unclassified hosts is gone; still add the host when adding a route.
- AdGuard rewrites are `terraform/adguard` `adguard_rewrite` (`rewrites.tf`). Do not add `adguard_user_rules` — one resource replaces the whole custom-rule list, including external-dns `$dnsrewrite` rules. When external-dns owns a name, delete it from the terraform map.

## Data and secrets

- App DB on CloudNativePG: add `Database` / `DatabaseRole` with `metadata.namespace: cloudnative-pg` (same ns as `Cluster/postgres`). RW host `postgres-rw.cloudnative-pg.svc`. Example: `kubernetes/hass/resources/database.yaml`. Cluster is `local-path`, 8Gi, `instances: 1`, pinned to the control plane. No Barman / `ScheduledBackup` — do not assume bucket backups exist. Compose Postgres on `.253` is gone; do not add users there.
- K8s secrets: 1Password via ExternalSecrets. Tag items so ESO can read them. Argo CD OIDC + GitHub PAT items need `ArgoCD External Secrets Operator`.
- New app data: static NFS PV+PVC (`storageClassName: nas-bind`, server `192.168.89.240`, `nfsvers=4.1`, reclaim `Retain`) pointed at the existing export path. Do not use hostPath `/mnt/nas-media` for app data — that bind exists only on the `k8s` LXC and pins the pod. Dynamic StorageClass `nfs` (`nfs-subdir-external-provisioner` `4.0.18`) creates a new subdir under `/volume1/media/k8s` and is not the default; do not use it for trees that already exist. Synology NFS clients today are `192.168.89.252` and `192.168.89.254`. Add a node IP to the export before scheduling a pod there, or the mount fails. Do not mount `/dev/dri` — the k8s LXC has the directory without `card0` / `renderD128`.

## Gotchas

- CoreDNS upstream is AdGuard `192.168.89.252` → RouterOS `192.168.89.1` → `1.1.1.1` (`forward` + `policy sequential`). kubeadm still owns the Deployment spec; this repo only ships the Corefile and a label patch. Application prune is off.
- Home Assistant and Mosquitto are hostNetwork on `192.168.89.252`. Mosquitto: anonymous `127.0.0.1:1883`, password `192.168.89.252:1883` (LAN devices), password on the pod IP (ClusterIP `mosquitto.hass.svc:1883`). Do not bind `0.0.0.0:1883`. In-cluster clients use `mosquitto.hass.svc`, not the node IP. HA `dnsPolicy: ClusterFirstWithHostNet`. Recorder DB is CNPG, but HA is hostNetwork — it uses the headless Service in `kubernetes/hass/resources/postgres-headless.yaml`, not ClusterIP. Zigbee USB is `/dev/ttyUSB0` on the lake node. `zigbee2mqtt-wifi` stays on the control plane — data is hostPath `/var/lib/hass/zigbee2mqtt-wifi`. `/var/lib/hass` must already exist (`hostPath` type `Directory`).
- AdGuard hostNetwork on the lake node (`:53`, `:3000`). UniFi hostNetwork (inform `:8080`; do not put Traefik's API back on `:8080`). WatchYourLAN hostNetwork (`:8840`). Authentik hostNetwork, HTTP `:9000` (forward-auth URL).
- Mediabox: Gluetun, qBittorrent, and SABnzbd share one pod so downloads stay on the VPN. `/dev/net/tun` must exist on the lake node. Library is hostPath `/mnt/nas-media`. Jellyfin has no GPU — software transcode only.
- Headlamp: `unsafeUseServiceAccountToken` plus `clusterRoleName: cluster-admin`. Anyone who passes Authentik is cluster-admin. Keep the Authentik app out of `user_accessible_apps`.
- n8n: `N8N_BLOCK_ENV_ACCESS_IN_NODE=true` — do not read `$env` from Code nodes. `N8N_SSRF_ALLOWED_IP_RANGES` is `192.168.89.1/32,192.168.89.200/32`. RouterOS API must be `http://192.168.89.1/rest`, not `https://router.dominiksiejak.pl`. Login → WAN allowlist workflow is `kubernetes/n8n/workflows/authentik-login-firewall.json` (credential `wan-allowlist`, header `x-webhook-secret`). After authentik apply, copy `tofu output -raw webhook_secret` into that credential. IPv4 only.
- No Grafana in the cluster. Dashboards live in Grafana Cloud (`terraform/grafana`, stack `dreewniak.grafana.net`). Apply the Authentik `grafana-cloud` OAuth app first. Needs a `glsa_` token in `defaults.auto.tfvars`. Do not recreate `grafana.dominiksiejak.pl`.
- Gitea data is hostPath `/mnt/nas-media/gitea` (not the `k8s/` prefix). Calibre books are `/mnt/nas-media/books`.
- `192.168.89.253` is down. No Portainer, Dozzle, compose Postgres, or compose Traefik. Do not recreate `stacks/` or the portainer IngressRoutes. CrowdSec LAPI lived there too — `crowdsec-bouncer` stays disabled until a live LAPI exists. RADIUS outpost is manual on `.252` (`kubernetes/authentik/resources/radius-outpost.yaml`); do not point it back at `docker-local`.
- OpenCode MCP lives in `.opencode/opencode.json` (gitignored). Copy from `.opencode/opencode.json.example`. Tokens are `{env:HA_URL}`, `{env:HA_TOKEN}`, `{env:N8N_API_KEY}`, `{env:ARGOCD_API_TOKEN}` — do not inline them. OpenCode interpolates `{env:VAR}` only, not `${env:VAR}`. Argo CD MCP is `argocd-mcp` stdio against `https://argocd.dominiksiejak.pl`. n8n URLs are `https://n8n.dominiksiejak.pl`. Kubernetes MCP is `kubernetes-mcp-server` pinned to context `k8s@lake` via `.opencode/kubeconfig-k8s-lake` (one context, generated, gitignored). Do not point it at `k8s.dominiksiejak.pl`. Cloudflare goes through the global Composio MCP, not `mcp.cloudflare.com`. Do not add a Docker MCP. Do not point it at `ssh://portainer`.
