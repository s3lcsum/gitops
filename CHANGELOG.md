# Changelog

### 10.10.2026

**OpenBao Phase 1.** `kubernetes/openbao` deploys OpenBao (Raft×1) at `openbao.dominiksiejak.pl` with Authentik OIDC and Shamir unseal keys from 1Password. `ClusterSecretStore/openbao` is ready for later cutover; live ExternalSecrets still use `onepassword`.

### 29.09.2026

**Left Portainer. The lab is Kubernetes.**

Compose on the old host is gone. Apps, identity, the edge, and Home Assistant now run on the lake node under Argo CD. Data sits on the NAS over NFS. Databases sit on CloudNativePG. Dashboards sit in Grafana Cloud. Public kube-apiserver passthrough is gone.

`vibe` joined as a Mac worker for AI workloads.

### 24.09.2026

**HashiCorp Vault is gone.** `stacks/vault/` and `terraform/vault/` left. Authentik OAuth app `vault`, Traefik `vaultpki` resolver, homepage/gatus/blackbox/AdGuard `vault.dominiksiejak.pl`, and the GCP KMS auto-unseal resources left with it. Compose secrets stay host-local `.env`. Terraform secrets come from gitignored tfvars or a data source in another repo. Before the next `terraform/gcp` apply, run `make -C terraform/gcp state-rm-legacy` so OpenTofu drops the KMS key and unseal service account from state (`prevent_destroy` would otherwise block the plan). Delete those GCP objects in the console if you want them gone for real. GCS prefix `gitops-vault` can be deleted from the state bucket. Portainer drops the stack on the next `make apply` in `terraform/portainer`. Authentik drops the `vault` app on the next authentik apply.

**Phase and Vaultwarden left the public repo too.** `stacks/phase/`, `stacks/vaultwarden/`, and the Phase render / consistency scripts went with them. Compose `.env` files are filled on the host again; k8s secrets stay on 1Password → External Secrets.

**KIND and miedzysztuka are gone.** `kind/` left the public repo (no more `vibe` cluster, no `argocd.vibe.local`). Kubernetes is the kubeadm node on lake, context `k8s@lake`. Cloudflare Pages project `miedzysztuka` left with it (`terraform/cloudflare/miedzysztuka.tf`).

**Argo CD is on `https://argocd.dominiksiejak.pl`.** Traefik-k8s terminates TLS; OIDC via Authentik (`argocd` slug, local admin off, `admins` → `role:admin`). Port-forward `8080` / CLI SSO `8085` still work as callback fallbacks. Client secret and the GitHub PAT come from 1Password (Servers items `argocd-oidc` and `argocd-github-repo-credentials`) through External Secrets.

### 23.09.2026

Public n8n webhooks that had no extra auth now require header `x-webhook-secret`. Authentik and the Focus shortcut keep their paths (`authentik-login`, `focus-work`). Toggl → calendar moved to `toggl-to-calendar`. The Ghostfolio CSV import webhook is gone. Names: WAN allowlist on login / `wan-allowlist` / `WAN_ALLOWLIST_SECRET`, Focus to Toggl / `focus-toggl` / `FOCUS_TOGGL_SECRET`, Toggl to Google Calendar / `toggl-to-calendar` / `TOGGL_CALENDAR_SECRET`. Authentik login → firewall is IPv4 only again — an IPv6 client IP gets a 400 and never touches RouterOS. Messenger is still Meta's webhook and was left as-is.

**Authentik → Cloudflare Zero Trust login.** New Authentik OAuth2 app `cloudflare` (callback `dominiksiejak.cloudflareaccess.com`) plus `cloudflare_zero_trust_access_identity_provider.authentik` in `terraform/cloudflare`. WAF country allowlist now skips `auth.dominiksiejak.pl/application/o/*` so Cloudflare's OIDC token/JWKS fetches aren't blocked from outside PL/DE/ES. Apply order: `terraform/authentik` then `terraform/cloudflare`. API token needs Access IdP write.

### 15.09.2026

**Phase for compose `.env` files.** Infisical died on paid OIDC; Phase Console is the replacement (`stacks/phase/`, `https://phase.dominiksiejak.pl`) with free Authentik OAuth via env vars. `make -C terraform/portainer apply` runs `render-secrets` (`scripts/render_phase_env.py` + `scripts/phase_env_map.yaml`) before rsync. Vault stays for Postgres static creds until those passwords are copied into Phase. Bootstrap `phase.env` is the one file Phase cannot store for itself — no Vault static role for `phase_user`. Spec: `docs/superpowers/specs/2026-09-15-phase-secrets-design.md`.

### 08.09.2026

**Focus ↔ Toggl InPost ↔ Google Calendar.** n8n now runs a bidirectional Work Focus controller and an authoritative Toggl→GCal sync:
- Workflows: `work-state-controller` — Focus `/webhook/focus-work` (Header Auth) + Toggl HMAC `/webhook/toggl-time-entry` + 3‑min cancellable debounce + 30s reconcile + SSH Shortcuts on `vibe`; `toggl-calendar-sync` — hourly + `/webhook/toggl-calendar-sync` onto calendar **Toggl**.
- Compose: n8n SSRF allowlist adds `192.168.89.200/32`, `NODE_FUNCTION_ALLOW_BUILTIN=crypto` for HMAC. Secrets live in `/opt/n8n/n8n.env` (see `n8n.env.example`).
- Spec: `docs/superpowers/specs/2026-09-08-focus-toggl-calendar-design.md` supersedes the 2026-08-26 Focus→Toggl draft.

### 07.09.2026

Removed **v-maintenance** — the Firebird box nobody talks to anymore. Gone: `stacks/v-maintenance/` (compose + env), the `v-maintenance` entry in `portainer/locals.tf`, the `templatefile()` hack in `portainer/main.tf` that inlined `ISC_PASSWORD` (the last `hashicorp/local` user there, so the provider went with it), and the opt-in `firebird.dominiksiejak.pl` slot in the Cloudflare `tunnel_apps` map. It had no Traefik host, so nothing else referenced it — no auth class, homepage tile, gatus probe or blackbox job to clean up. Containers and the `firebird-data` volume get dropped on the next `make apply` in `terraform/portainer`.

### 06.09.2026

Removed **Ghostfolio** — Wealthfolio covers personal finance now. Gone: `stacks/ghostfolio/` (compose + `gf-redis` sidecar), the `ghostfolio` Authentik OAuth2 app, `ghostfolio_db` / `ghostfolio_user` in the postgres + vault locals, homepage tile, gatus probe, blackbox job, AdGuard DNS rewrite, and its auth classification. Containers and the Postgres DB were dropped with it.

### 06.09.2026

Removed **Infisical** — no OIDC SSO in the community edition (it's an Enterprise `LICENSE_KEY` feature), so it was a dead end as the Vault replacement. Gone: `stacks/infisical/` (compose + env), the `infisical` Authentik OAuth2 app, `infisical_db` / `infisical_user` in the postgres + vault locals, homepage tile, gatus probe, blackbox job, and its auth classification. Containers, the Redis volume, and the Postgres DB were removed with it. Vault stays until a replacement with free OIDC SSO shows up.

### 06.09.2026

Housekeeping pass — unstuck `make apply` and a few crash loops:
- **Infisical actually boots now.** It was in `portainer/locals.tf` without `stacks/infisical/infisical.env`, so Portainer could never start it and every `make apply` re-planned `active = false -> true` forever. Added the env file (gitignored, rsynced like every other stack), and pointed `REDIS_URL` at `infisical-redis` — `gf-redis` also claims the `redis` alias on the shared `database` network, so plain `redis` authenticated against ghostfolio's instance. Dropped Infisical from the Vault static roles (Vault is retiring; a static role would rotate the password out from under the `.env`). SMTP reuses the vaultwarden relay.
- **Gitea is back.** Both bleve indexes (`issues.bleve`, `repos.bleve`) were built by a different Gitea version and failed with `camelCaseKeepWhole` / `codeTokenizer` not registered. Renamed them; Gitea regenerates on boot.
- **unifi-db pinned to `mongo:7.0.40`.** MongoDB 8.0+ refuses to start on Linux kernel >= 6.19 (tcmalloc/`rseq`, [SERVER-121912](https://jira.mongodb.org/browse/SERVER-121912)) and crash-looped on the 7.x Proxmox kernel. 7.0.x is unaffected. **The old UniFi database was replaced with a fresh one** — 8.x data can't be read by 7.x, and `mongodump` needs a running 8.x, so devices need re-adopting. Don't bump this back to 8.x unless the host kernel is pinned below 6.19.
- Tooling: `terraform/base.Makefile` grew the `validate`/`fmt`/`check`/`clean`/`destroy` targets AGENTS.md always claimed (`make check` was broken in all 13 modules); `terraform/postgres` now defaults `POSTGRES_SSH_TARGET=portainer` since Postgres is localhost-only on the host; `check-consistency.py` got an `EXTERNAL_PROBES` allowlist so `--fix` stops deleting the google/inpost/easypack24/usertesting WAN canaries; gatus now probes all 12 routed hosts it was missing.

### 06.09.2026

Stood up **Infisical** as the Vault replacement target — `stacks/infisical/` (pinned `infisical/infisical:v0.165.6` + Redis sidecar), Traefik at `infisical.dominiksiejak.pl`, DB via central Postgres (`infisical_db` / `infisical_user` in postgres+vault locals), Authentik OAuth2 app ready for licensed OIDC SSO later. Vault stays until consumer cutover.

### 30.08.2026

Security follow-up: Portainer tofu talks to `https://portainer.dominiksiejak.pl` with TLS verify (no hardcoded `skip_ssl_verify`); Firebird off tunnel defaults; Authentik forwardauth stops trusting client `X-Forwarded-*` + pinned `TRUSTED_PROXY_CIDRS`; every Traefik host must be classified in `scripts/auth_classification.yaml` (`make consistency`); dual-WAN (direct CrowdSec+Auth vs CF tunnel/Access) documented as intentional; Vault marked retiring; `terraform/terraform-cloud` Makefile refuses apply.

### 25.08.2026

**Argo CD installs the remote chart.** `kubernetes/argocd/resources/application.yaml` pins `argo-cd`, `values.yaml` overrides it, and `resources/` is Kustomize (Application, ApplicationSet, ExternalSecrets). Bootstrap with `make -C kubernetes/argocd bootstrap`; the in-cluster Application tracks `main` and syncs manually.

### 23.08.2026

**Messenger → Home Assistant AI assistant.** Family members can now message the Facebook Page and get answers/actions from Home Assistant, authenticated as the requester:
- New n8n workflow **Messenger Assistant** (`/webhook/messenger`) verifies Meta's webhook handshake, maps PSID → person (Dominik/Jan/Dantua/Oliwia), calls HA's `/api/conversation/process` with a per-person `conversation_id`, and replies through the Messenger Graph API.
- Identity is n8n-injected (person name + stable per-person conversation thread); uses a dedicated HA long-lived token + a Messenger page-token credential stored in n8n.
- Cloudflare: added a high-priority `skip` rule to the country-allowlist ruleset so the `/webhook/messenger` path on `n8n.dominiksiejak.pl` bypasses the PL/DE/ES geo-block (Meta's servers are US-hosted), while the rest of the zone stays allowlisted.

### 16.08.2026

**Calibre** got a full reproducible automation + acquisition story:

- CWA (`calibre.dominiksiejak.pl`) stays the single writer of the shared library, and the desktop GUI (`calibre-gui.dominiksiejak.pl`, Authentik-gated) was repointed at that same library. Both now live on `books/library`.
- The whole setup is restore-from-code: `stacks/calibre/seeds/` carries the GUI `global.py.json`, CWA `cwa_settings`/`settings`, and DeDRM v10.0.3 in the *active* config (`/config/.config/calibre/plugins/`) — the baked-in 7.2.1 was never loaded. `make calibre-restore` rebuilds everything.
- `make calibre-plugins` installs Quality Check, Manage Series, Kobo Utilities, EpubMerge, KindleUnpack into the GUI (sha-pinned manifest; KoboTouchExtended dropped — it doesn't load in linuxserver/calibre 9.13's frozen-python build, and CWA already does KEPUB + Kobo wifi sync).
- Metadata provider order puts LubimyCzytac first for Polish books, google/others fall back for EN/ES.

**Book acquisition:** baseline for Readarr + rreading-glasses (plan in progress — see below).

### 15.08.2026

**Monitoring as code.** Revamped `stacks/monitoring/` around config-as-code: added a Prometheus [Blackbox exporter](https://github.com/prometheus/blackbox_exporter) probing 25+ public endpoints (`blackbox-*` jobs in `victoria-metrics/promscrape.yaml`), a `scraparr` exporter in `stacks/mediabox/` exporting Sonarr/Radarr/Prowlarr metrics, and moved Grafana to CasC — dashboards for Node, PostgreSQL, Traefik, VictoriaMetrics, Blackbox and the scraparr service are provisioned from `stacks/monitoring/grafana/provisioning/dashboards/` against a single `victoria-metrics` datasource (no stale `$DS_*` refs), and alert rules `Synthetic service down` (`min(probe_success) by (instance) < 1`) and `VictoriaMetrics down` (`up{job="victoria-metrics"} < 1`) are provisioned from `provisioning/alerting/alerting.yaml` into the Monitoring folder, routed to an `all-channels` receiver (Telegram + SMTP email). Added a `terraform/grafana/` module (Terraform Cloud workspace `gitops-grafana`) that creates a provisioner service account + token via the API — the one thing CasC provisioning can't express.

End-to-end verification on 15.08.2026: the first rule draft fed a `== 0` expression into a `gt 0` threshold, so a `0` value never crossed it and the rule stayed inactive — caught live by stopping `sonarr` while the `blackbox-sonarr` probe read 0 for several minutes. Fixed both rules to threshold the raw metric with `lt 1`; re-verified the cycle: sonarr stop → `Synthetic service down` firing (health ok, correct instance), sonarr start → resolved to normal. `VictoriaMetrics down` fires via the datasource-error path (`execErrState: Alerting`) when VM is unreachable and also resolves cleanly on restart. Firing states were delivered into Alertmanager under the `all-channels` route. External Telegram/SMTP delivery itself could not be observed from the shell — only inferred from Alertmanager state.

### 04.08.2026

A quiet week of maintenance across the stacks. The usual daily cron image updates ran through late July, and on top of that most services were pinned to explicit version tags instead of `:latest` — calibre to 9.12.0, zigbee2mqtt to 2.13.0, netbox to v4.6.5, traefik to v3.7.10, n8n to 2.32.7, homepage to v1.13.2 and one of the gatus to v5.36.0. Gatus picked up a bit more monitoring: a custom webhook alert type that POSTs alert payloads to the Unifi server at `http://192.168.89.130:8645/`, plus a new `unifi` endpoint, and enabled `N8N_API_ENABLED=true` in `stacks/n8n/n8n.env.example` so the n8n public API is on. In `stacks/traefik/dynamic.yaml` the Hermes service now points at port 8788 instead of 8787 (after its WebUI split from the agent gateway) and the ArgoCD backend flipped `passHostHeader` to false. On the Terraform side providers were pinned to exact versions, dropping the `~>` ranges — a notable jump for cloudflare 4.x to 5.22.0 — plus bumps for b2 0.13.1, google 7.41.0, netbox 5.7.0, portainer 1.34.1, the tfe provider to 0.79.0, postgresql 1.27.0 and vault 5.10.1, with OpenTofu itself moved to 1.12.5 and the `terraform/gcp` and `terraform/portainer` lock files refreshed accordingly.

### 23.07.2026

Added Hermes WebUI OIDC SSO via Authentik — created the `hermes` OAuth2 provider in `terraform/authentik/locals.tf`, added explicit `grant_types` to `authentik_provider_oauth2` in `applications.tf` to fix a malformed-request error from Authentik. Migrated Homepage from Docker proxy auto-discovery to a manual `services.yaml` in `stacks/homepage/`, added an AdGuard entry for `homepage.*` labels, and added the AdGuard stack itself to Authentik's app list. Added a Traefik dashboard router at `traefik.dominiksiejak.pl` behind Authentik, and WireGuard `post_up`/`pre_down` commands in `terraform/routeros/wireguard.tf` that resolve `dns.dominiksiejak.pl` dynamically so DNS still works when the VPN is up. Replaced the AdGuard `conf` named volume with a bind mount at `/opt/adguard/conf` and removed the `traefik-adguard-sync` sidecar — it wasn't reliable and manual DNS entries work better. Cleaned up the old Profilarr/recyclarr migration — the latter was already removed. Bumped unifi-db mongo from 8.0.4 to 8.3.4, added a 10s timeout for the hass-timemachine Gatus endpoint to stop spurious failures. All daily image update cron commits are in as usual.

### 29.06.2026

**Domain flattened.** Dropped the `lake.` subdomain entirely — services now live straight at `*.dominiksiejak.pl`. Updated Traefik defaultRule, cert SANs, `*.lake` wiped from the SANs list. Changed Authentik OIDC redirect URIs, Vault allowed domains, Gitea provider URL, NetBox and Vault addresses, and every compose file that still had the old `lake.` ref. Traefik HTTP (port 80) now does a permanent redirect to HTTPS instead of passing through CrowdSec first.

**Homepage dashboard.** New `stacks/homepage/` stack running [Homepage](https://gethomepage.dev/) with Docker socket proxy for auto-discovery. Every compose file got `homepage.*` labels — groups, names, icons — so the dashboard populates itself. Added `stacks/homepage/config/` with settings, services, bookmarks, widgets, and docker.yaml. Also added `stacks/adguard/traefik-adguard-sync.env.example` for the AdGuard ↔ Traefik sync sidecar.

**Media stack rework.** Dropped Bazarr (wasn't really using it for Polish subs). Switched VPN gateway from Mullvad/OpenVPN to NordVPN/WireGuard in Gluetun. Simplified `sabnzbd.env.example` — all config is now managed through the web UI and persisted in the volume, no env vars needed. Bumped Sonarr `4.0.17` → `4.0.19`.

**Traefik security.** Added `remote@file` middleware on most router rules for internal-only services. Removed `frameDeny` from security headers (was breaking some UIs). Added `customRequestHeaders` for X-Remote-Bypass on the `remote` middleware. Removed `crowdsec-bouncer` from the HTTP entrypoint — port 80 now redirects straight to HTTPS.

**Cleanup.** Deleted Project N.O.M.A.D stack (`stacks/nomad/`) — wasn't actively used. Removed all `.cursor/rules/` files (16 of them) since the knowledge is consolidated in `AGENTS.md`. Deleted stale `docs/superpowers/` planning/spec docs for the HA lovelace dashboard.

**Terraform.** Updated `terraform/portainer/locals.tf` — added `homepage` and `gitea` to the active stack list. Removed `bazarr` and `nomad` references from `terraform/authentik/locals.tf` and `terraform/gitea/locals.tf`. Added `redirect_uri_type` to Authentik OAuth2 provider config. Dropped `lake.dominiksiejak.pl` from Vault's `allowed_domains`. Regenerated `.terraform.lock.hcl` for gitea, postgres, and routeros modules.

### 12.04.2026

**Gitea** stopped living on a Docker named volume — `/data` is bind-mounted to the NAS (same energy as the mediabox NFS pattern), and Traefik gets `traefik.docker.network: proxy` so it doesn’t pick the wrong attach point. **`gitea.env.example`** now spells out the Authentik OIDC callback / source-name footguns so I don’t rediscover them at 2am.

**Home Assistant** stack grew **HA Time Machine** (`ghcr.io/saihgupr/homeassistanttimemachine`): Traefik + Authentik at `timemachine.dominiksiejak.pl`, secrets via `/opt/hass/timemachine.env` with `stacks/hass/timemachine.env.example` as the template, exports landing under `/opt/hass/timemachine` on the host.

**NetBox** Compose image bumped to **v2.5.13**; Terraform **netbox** provider lock moved with it.

**Authentik** Terraform: **Firefly III** and **WatchYourLAN** are real forward-auth proxy apps now (WatchYourLAN got yeeted off the dashboard-only list). **`all_app_uuids`** uses `setintersection` against resources in state so renamed/missing apps don’t brick evaluation. Dropped a stale `import` block on the embedded proxy outpost.

Regenerated **`.terraform.lock.hcl`** files across modules so they also record **`registry.terraform.io/*`** provider hashes — `terraform init` stops whining even when I’m not living purely in OpenTofu-land.

More **12.04** tweaks after that landed: **Postgres** is **localhost-only** on the host (`127.0.0.1:5432`) so random LAN clients can’t poke the DB; **`terraform/postgres/Makefile`** now knows **`POSTGRES_SSH_TARGET`** and spins an SSH **`-L`** tunnel for **`tofu plan`/`apply`** from a dev machine when you’re not on the Portainer box (sets **`TF_VAR_postgres_host`** / **`TF_VAR_postgres_port`** for the run). **Vault** no longer publishes **`8200`** on the host — it’s **Traefik-or-bust**, which is the whole point of the proxy stack.

**Traefik** got **`host.docker.internal:host-gateway`** so file-provider / container routers can hit **host-networked** **Home Assistant** and **ESPHome** without hard-coding a DHCP address. **HASS stack**: **Mosquitto** has a **`mosquitto_sub`** healthcheck, **HA** + **zigbee2mqtt** **`depends_on`** with **`condition: service_healthy`**, **HA Time Machine** is gated behind compose **`profile: timemachine`** (set **`COMPOSE_PROFILES=timemachine`** in Portainer or your shell when you want it; **`timemachine.env.example`** documents that). **zigbee2mqtt** config sets **`frontend.url`** to the Traefik hostname so links don’t lie.

**Authentik** compose: **`AUTHENTIK_LOG_LEVEL`** back to **`info`**, **Docker socket** mounted **`:ro`** (same **`:ro`** treatment for **Dozzle**). **Authentik** Terraform adds **`zigbee2mqtt`** to the user-facing app list; the module lockfile is **OpenTofu-only** now — yeeted the duplicate **`registry.terraform.io/*`** stanzas.

README + MkDocs got a sanity pass: **services** and **repo tree** now track **`terraform/portainer/locals.tf`** (added **homarr**, **monitoring**; evicted dead stack names). Replaced the giant icon grid with a maintainable table, and spelled out **AdGuard** as **LXC** plus **Talos/K8s** as “not in `stacks/`”. Yeeted the empty **Stalwart** runbook from **MkDocs** nav.

### 6.04.2026

Swapped **Terraform Cloud** remote state for a **GCS** bucket — wired backends across the Terraform roots, added a batch **TFC→GCS** migration script plus `migrate-all-tfc` / `bootstrap-tfstate-bucket` make targets so I’m not clicking through fifty workspaces. On the **Proxmox** side: **Talos** cluster resources, optional **Calico** bootstrap after kubeconfig lands, and gitignored `terraform/proxmox/generated/` for Talos/kubeconfig artifacts.

Pushed more **Kubernetes** platform bits: **Grafana**, **VictoriaMetrics**, **Vector**, **Stakater Reloader**, **Calico**, **Grafana Alloy** (incl. templates), plus **homelab** manifests and ArgoCD / **n8n** tweaks. Pruned legacy **Docker Compose** stacks from `stacks/` (AdGuard, CyberChef, Firefly, OmniTools, Watchtower) since those workloads moved to the cluster, trimmed **Gatus**, and refreshed **NetBox** IPAM data + **MkDocs** networking notes.

### 5.04.2026

Renamed the Seerr bits in docs (Jellyseerr is legacy branding; Docker image name unchanged). Fixed the Authentik `user_accessible_apps` slug to match `seerr`, pointed the Gitea mirror at the new GitHub repo, and added a Talos DHCP reminder so apply doesn’t look like it’s hanging forever.

### 4.04.2026

OpenTofu + provider refresh, pinned a few container images, fixed CI’s tofu pin (it was embarrassingly old). Threw a note on Seerr about OIDC still being preview-only upstream.

### 7.03.2026

Updated all dependencies to latest versions — Docker images, Terraform providers, and OpenTofu itself.

### 05.02.2026

Added a new `smtp` stack running Stalwart SMTP server for send-only notifications. It's exposed publicly on ports 587/465 with SMTP AUTH required, so apps can connect from anywhere without turning into an open relay. Admin UI is behind Traefik at `smtp.dominiksiejak.pl`. Planning to relay outbound through Zoho since my dynamic IP would tank deliverability otherwise.

### 03.02.2026

Brought back Watchtower as a Portainer-managed stack (using the maintained `ghcr.io/containrrr/watchtower` image, not the abandoned one). Also removed the leftover `wud.*` label from the Postgres stack since I don’t want WUD poking at DB/Vault-tier stuff.

Also bumped the centralized Postgres stack to **v18** and added a safe `17 -> 18` migration script (logical dump + filesystem snapshot + restore into a fresh v18 data dir) so I can roll forward/back without sweating data loss.

### 02.02.2026

Swapped Uptime Kuma for Gatus as the uptime monitoring solution. Gatus is simpler, uses config-as-code (YAML), and doesn't need a database - just SQLite for history. Migrated all monitors from Terraform to the Gatus config file. Removed the whole `terraform/uptime-kuma/` module and the Terraform Cloud workspace for it. Updated Authentik, Vault, and Postgres configs to drop the Uptime Kuma references. Status page now lives at `status.dominiksiejak.pl`.

### 11.01.2026

Swapped the Terraform CLI for OpenTofu (`tofu`) across the repo. All module `Makefile`s now run `tofu`, pre-commit uses the OpenTofu hooks, CI installs OpenTofu. Vault now manages all OAuth secrets (for example, Authentik's client secrets), so there is no longer any global tfstate access for Authentik. Secrets are injected at runtime via Vault instead of being stored in shared state.

### 16.12.2025

README cleanup: the "Apps on Portainer" table now actually lists everything that's sitting in `stacks/` (adguard/keycloak/openldap included). Also expanded the whole mediabox setup into the individual apps (Jellyfin, *arrs, downloaders, VPN gateway), so it's not a mystery box anymore. Pulled proper icons into `docs/assets/` for the mediabox apps too (incl. FlareSolverr) — README is now local-images-only.

### 15.12.2025

Ripped out ZITADEL and went back to Authentik after realizing it was just causing more headaches than it was worth. Re-added Authentik service with full Docker Compose setup, updated PostgreSQL config to handle Authentik DB creds properly, and cleaned up all the ZITADEL cruft from Terraform. Also added Diun for Docker image update notifications. Basically reverting back to what was working before.

### 23.11.2025

Wrote up new repo rules for Docker Compose stacks and Terraform/GCP configs, gutted the unused ArgoCD/Cert-Manager/chart cruft, and rewired the mediabox/Traefik/Portainer pieces: Configarr is gone, Vaultwarden got its own stack plus DB creds, and Terraform-side references now match the fresh stack layout. Lost some commits while switching PCs before I could push them (the HDD format nuked the old machine), so this is the history that actually made it up here.

### 23.08.2025

Swapped Authentik with ZITADEL due to ongoing configuration issues. Despite limited documentation for ZITADEL, it's an actively growing project with promising potential.

### 22.08.2025

Switched back from Podman to Docker due to too many compatibility issues. Docker has better ecosystem support and fewer configuration headaches.

### 20.08.2025

Upgraded hardware by replacing old wally-1 terminal with new lake-1 server (Mini PC FIREBAT T8 Pro Plus Intel N100 16GB DDR5 / 512GB) for better performance. Also migrated domain from wally.dominiksiejak.pl to lake.dominiksiejak.pl, updating 25+ configuration files across Docker stacks, Helm charts, and Terraform modules. Updated all Traefik routing, SSL certificates, DNS, and service URLs.

### 31.07.2025

Major infrastructure improvements: added n8n for workflow automation, PostgreSQL for database storage, and Grafana Synthetic Monitoring Agent. Enhanced development tools with pre-commit hooks, GitHub Actions, and improved CI/CD pipeline. Improved Traefik routing and security, updated Docker images, added healthchecks. Removed mktxp stack and .cursorrules file. Updated various configurations and documentation.

### 7.07.2025

Replaced Nginx Proxy Manager with Traefik as the reverse proxy and added CrowdSec security integration. Added mediabox stack for home media server setup. Removed VictoriaMetrics stack since moving to Grafana Cloud. Updated all stack configurations to use Traefik labels.

### 25.05.2025

Refactored the Terraform code slightly to reduce repetition. I also removed 'watchtower' — it's a great tool, but I prefer to update everything manually.

### 21.05.2025

I have configured the Google SSO for Authentik with the terraform. However, I did some changes manually in the UI for the flows/stages, as they're super difficult to configure via terraform.

### 20.05.2025

I have just refactored Portainer stacks, so I won't have to deal with many resources, but have done it all in a single array. Before, I thought it would be better this way, but it wasn't worth it.

### 18.05.2025

I'm reverting from Portainer's GitOps option that was automatically pulling stacks from this repository. The delay between commits and actual changes in Portainer was frustrating. Plus, I couldn't make any temporary changes in stacks. I'd rather execute `terraform apply` to keep everything in one place.

### 17.05.2025

Because I accidentally deleted my authentik environment variables, I decided to give authelia a shot. I've heard only good things about it, and it's fully configurable via YAML files. It seemed promising, but I felt like I was missing some options that worked perfectly out-of-the-box in authentik. I tried to configure it, but ended up restoring authentik from backup anyway.
