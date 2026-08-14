# Grafana Monitoring — CasC-First Design

## Goal

Turn `stacks/monitoring` into a production observability layer with on-prem synthetic
monitoring and alerting, while honoring the rule: **prefer `stacks/` (compose + CasC
provisioning) over Terraform wherever Grafana 13 supports it.** Terraform is used only
for what CasC physically cannot manage.

**Scope decisions (approved during brainstorming):**

- Synthetic monitoring = **blackbox_exporter → VictoriaMetrics + Grafana alert rules**
  (self-hosted; no Grafana Cloud).
- **Maximize stacks**: dashboards, alert rules, contact points, notification policy,
  templates all live as CasC provisioning files in `stacks/monitoring`.
- Dashboards sourced from **Grafana.com JSON committed to the repo** (CasC dashboard
  files), not `gnetId` terraform resources.
- **OIDC is untouched** — already works via compose `GF_AUTH_GENERIC_OAUTH_*` +
  `terraform/authentik` app (`role` claim: admins→Admin, users→Editor).
- **Explore→VM is untouched** — VictoriaMetrics is already the default datasource.
- Default assumption (flag if wrong): **keep gatus** running as the public status page;
  **no Teams/group-sync** — single-org access, OIDC roles already grant Admin/Editor.

This design **supersedes** `2026-07-07-grafana-terraform-module-design.md` (which put
dashboards/alerting into Terraform via `gnetId`). The new split is CasC-first.

## 1. What CasC can and cannot manage (Grafana 13)

| Capability | CasC provisioning? | In this design |
|---|---|---|
| Data sources | ✅ `datasources.yaml` | stays as-is (has VM) |
| Dashboards + folders | ✅ `dashboards/` + `dashboards.yaml` | **stacks** (new) |
| Alert rules (rule groups) | ✅ `alerting.yaml` | **stacks** (new) |
| Contact points | ✅ `alerting.yaml` (incl. Telegram, email) | **stacks** (new) |
| Notification policies | ✅ `alerting.yaml` (incl. mute timings) | **stacks** (new) |
| Message templates | ✅ `alerting.yaml` | **stacks** (new) |
| Service accounts + tokens | ❌ API only | **terraform/grafana** (new) |
| Teams / org users | ❌ API only | out of scope (assumed) |
| OIDC config | ❌ env/ini only | untouched (compose) |
| Plugins / server config | ❌ env only | untouched (compose) |

## 2. Files changed / added

### 2.1 `stacks/monitoring/compose.yaml` (modify)

- Add `blackbox-exporter` service:
  - image `prom/blackbox-exporter:v0.26.0` (verify latest pinned tag)
  - networks: `metrics`, `proxy` (must reach all proxied apps)
  - no Traefik labels (not user-facing)
  - command with `--config.file=/config/blackbox.yaml`

### 2.2 `stacks/monitoring/victoria-metrics/promscrape.yaml` (modify)

- Add `blackbox` scrape job: `params.module=[http_2xx]`, `metrics_path=/probe`,
  `relabel_configs` for `__param_target` → `instance`.
- Static target list mirrors current `stacks/gatus/config.yaml` endpoints
  (portainer, vault, netbox, dozzle, traefik, gitea, arr stack, jellyfin, homepage,
  postgres-exporter, etc.), all over HTTPS via **Traefik** (`https://<svc>.dominiksiejak.pl`)
  exactly as gatus does — this exercises the real user path (TLS, routing, auth
  redirects) and needs no knowledge of each app's internal port. Probes originate from
  the `proxy` network, so no hairpin.
- Note: a TCP module may be added for non-HTTP services if needed (Phase 2).

### 2.3 `stacks/monitoring/blackbox-exporter/blackbox.yaml` (new)

- `http_2xx` module: preferred IP protocol `ip4`, follow redirects, `fail_if_body_not_matches` empty (simple), timeout matching gatus (3s).

### 2.4 CasC alerting — `stacks/monitoring/grafana/provisioning/alerting.yaml` (new)

- **Contact points** (secrets via `${VAR}` env substitution, values live in the
  service's `.env`):
  - `telegram-act`: type `telegram`, `botToken` `${GRAFANA_TELEGRAM_BOT_TOKEN}`,
    `chatid` `${GRAFANA_TELEGRAM_CHAT_ID}`.
  - `email-smtp`: type `email`, addresses → `root@mail.dominiksiejak.pl`,
    `dreewniak@gmail.com`. SMTP transport configured via `GF_SMTP_*` env (below).
- **Notification policy**: default routes both `telegram-act` and `email-smtp`;
  policies keyed on `service="up"` (synthetic), `service="metrics"` (VM incidents),
  and default catch-all.
- **Rule groups** (PromQL against `VictoriaMetrics` datasource, `uid` `victoria-metrics`):
  - `synthetic-monitoring`: `probe_success == 0` per instance → "Service down"
    (label `service="up"`).
  - `victoria-metrics`: `up{job="victoria-metrics"} == 0` → "VM down";
    high CPU (`process_cpu_seconds_total` rate), disk usage, memory meters.
  - `traefik`: 5xx/error-rate spike rule.
  - Evaluation: every 60s, `for: 2m`, pending→firing.
- **Message templates**: minimal `default` template touched only if default looks bad.

### 2.5 CasC dashboards — `stacks/monitoring/grafana/provisioning/dashboards/` (new)

- `dashboards.yaml` provider: `folder: "Metrics"` (or per-service folders), `allowUiUpdates: false`.
- JSON files committed from Grafana.com (choose pinned revisions):
  - Traefik (e.g. gnetId 19190 / official Traefik dashboard)
  - VictoriaMetrics (gnetId 10229)
  - Blackbox Exporter (gnetId 7587)
  - PostgreSQL (gnetId 9628)
  - Node Exporter Full (gnetId 1860)
  - Authentik (gnetId 19870 or equivalent)
  - Jellyfin (gnetId — verify)
  - arr stack (Sonarr/Radarr/Prowlarr via komunarr-style or individual, verify)
- Each downloaded JSON normalized (datasource uid → `victoria-metrics`).

### 2.6 `stacks/monitoring/grafana.env` + `.env.example` (modify)

- Add to **example**: `GRAFANA_TELEGRAM_BOT_TOKEN`, `GRAFANA_TELEGRAM_CHAT_ID`,
  `GF_SMTP_ENABLED=true`, `GF_SMTP_HOST=`, `GF_SMTP_USER=`, `GF_SMTP_PASSWORD=`,
  `GF_SMTP_FROM_ADDRESS=root@mail.dominiksiejak.pl`.
- Real `.env` gets values (bot token / chat id from existing `stacks/gatus/gatus.env`;
  SMTP creds from `stacks/gatus/gatus.env`). Not committed.
- Same keys added to `blackbox-exporter.env`/service if env-file pattern preferred
  for the probe config (`--config.file=/config/blackbox.yaml`).

### 2.7 `terraform/grafana` (new module, minimal)

Only CasC-impossible resources:

```
terraform/grafana/
├── providers.tf       # cloud {}, grafana/grafana pinned, hashicorp/vault
├── variables.tf       # grafana_url, vault_token
├── data.tf            # vault_kv_secret_v2 → kv/grafana/admin (admin user+pass)
├── main.tf            # grafana_service_account + grafana_service_account_token
├── outputs.tf         # SA id/name; token marked sensitive
└── Makefile           # include ../base.Makefile
```

- Provider auth: admin basic-auth from Vault (`kv/grafana/admin`), like the old
  07-07 design. (Admin creds also exist in `grafana.env`; Vault remains the source
  for Terraform to match repo convention.)
- Resource: `grafana_service_account` "external-tools" + rotating token output.
  Currently no consumer exists; module is scaffolded + verified reachable.
- Backend: Terraform Cloud `cloud {}`, workspace `gitops-grafana`
  (consistent with all other modules).
- Pin provider version exactly, `required_version = ">= 1.11.5"`.

## 3. Data flow

```
user/script ──HTTPS──► traefik ──► blackbox-exporter (probe /probe)
   ▲                                                    │
   └── gatus status page (unchanged)                    └─► http_2xx result
                                            victoria-metrics ◄─ scrape (60s)
                                                  │
                                    grafana (CasC dashboards + alert rules)
                                                  │
                          alerting.yaml ──► telegram-act + email-smtp (firing)
```

## 4. Alerting behavior

- Synthetic probe fails 4 consecutive checks (matches gatus threshold via `for: 2m`
  at 60s eval) → one alert, both channels.
- Channel behavior: Telegram = noisy/fast; email = summary. Both in default policy.
- `send-on-resolved` default; resolution notifications go to both.

## 5. Error handling / rollback

- Remove `blackbox` job from `promscrape.yaml` + stop container → back to today.
- CasC `alerting.yaml` / dashboard files are declarative: delete file + restart
  grafana → gone. Grafana reloads provisioning on save (file polling).
- Terraform module is additive; no existing resources touched.

## 6. Testing / verification

1. `docker compose up -d blackbox-exporter` on monitor stack → container healthy.
2. VM `/targets` shows `blackbox` job UP.
3. Grafana: dashboards render with data (Traefik, VM, Node, Postgres).
4. CasC alerting: `probe_success == 0` rule fires in test by stopping a container.
5. Telegram + email received on firing and resolved.
6. `terraform/grafana` `make plan` clean; SA token output emitted.
7. `pre-commit run --all-files`, `make check` for affected terraform; then portainer
   `make apply` syncs stacks (per AGENTS.md workflow: run `make apply` in
   `terraform/portainer` and restart containers with mounted configs).

## 7. Out of scope (Phase 2, if desired)

- TCP/ICMP synthetic modules.
- Deprecating gatus / moving status page into Grafana.
- Teams/group-sync + per-team dashboards.
- RBAC role customizations beyond defaults.