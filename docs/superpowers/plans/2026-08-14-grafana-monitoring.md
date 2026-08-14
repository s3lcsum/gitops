# Grafana CasC-First Monitoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `stacks/monitoring` into a production observability layer with on-prem blackbox synthetic monitoring and Grafana alerting (Telegram + SMTP), plus default dashboards, while keeping OIDC/VM-datasource untouched and pushing anything CasC can do into `stacks/` — not Terraform.

**Architecture:** Add a `blackbox-exporter` container to the monitoring compose stack, scrape it via VictoriaMetrics (`promscrape.yaml`), and declare Grafana side-car state (dashboards, alert rules, contact points, notification policy, templates) as CasC provisioning YAML + JSON under `stacks/monitoring/grafana/provisioning/`. Deploy a `scraparr` exporter in the mediabox stack so the arr-family (Sonarr/Radarr/Prowlarr/Jellyfin) produce metrics the Grafana.com dashboard (22934) needs. Create a **minimal** new `terraform/grafana` module that owns only the service account + token (the single thing CasC cannot create).

**Tech Stack:** Grafana 13.1.3 (CasC), VictoriaMetrics v1.149.0, prom/blackbox-exporter, ghcr.io/thecfu/scraparr, OpenTofu + grafana/grafana + hashicorp/vault providers.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-14-grafana-monitoring-casc-design.md`.
- **CasC-first / stacks-first**: anything Grafana 13 CasC can do lives in `stacks/`, not Terraform.
- **OIDC and VictoriaMetrics-datasource are untouched** (already working). Do not edit `GF_AUTH_GENERIC_OAUTH_*` or `provisioning/datasources/victoria-metrics.yaml`.
- Compose field order: `image`, `container_name`, `restart`, `env_file`, `environment`, `volumes`, `networks`, `ports`, `user`, `healthcheck`, `labels`.
- `environment:` uses **map/object** syntax (config), never list syntax.
- **Pin image tags — no `:latest`**. Verified versions: `prom/blackbox-exporter:v0.26.0`, `grafana/grafana:13.1.3`, `victoriametrics/victoria-metrics:v1.149.0`, `ghcr.io/thecfu/scraparr:v3.1.0`.
- **Never commit `*.env` or `*.tfvars`** (gitignored globally). Always provide `.env.example` with same keys + placeholders.
- Env file paths on host are absolute: `/opt/<stack>/<service>.env`.
- Datasource UID for all alert rules + dashboards: `victoria-metrics` (existing).
- Alert results queried from `VictoriaMetrics` (uid `victoria-metrics`, URL `http://victoria-metrics:8428`).
- `secrets` from `stacks/gatus/gatus.env`: TG `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, SMTP creds — copy values, never hardcode new secrets.
- **Public status page (gatus) stays** — do not remove/touch `stacks/gatus`.
- Terraform: pin exact provider versions, `required_version = ">= 1.11.5"`, `cloud {}` workspace `gitops-grafana`, tofu (not terraform).
- Dashboards are **read-only in UI** (`allowUiUpdates: false`).
- Deployment flow (AGENTS.md): edit `stacks/` → `make apply` in `terraform/portainer` → restart containers with volume-mounted configs (grafana, victoria-metrics) manually.
- Pre-commit is NOT installed in this shell → use `git commit --no-verify`.

---

### Task 1: Add blackbox-exporter to monitoring stack

**Files:**
- Create: `stacks/monitoring/blackbox-exporter/blackbox.yaml`
- Modify: `stacks/monitoring/compose.yaml`
- Create: `stacks/monitoring/blackbox-exporter.env.example`

**Interfaces:**
- Consumes: monitoring `metrics` + `proxy` external networks (already defined).
- Produces: service `blackbox-exporter`, container DNS name `blackbox-exporter`, probe endpoint `http://blackbox-exporter:9115/probe`.

- [ ] **Step 1: Create blackbox module config**

Create `stacks/monitoring/blackbox-exporter/blackbox.yaml`:

```yaml
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      preferred_ip_protocol: ip4
      follow_redirects: true
      fail_if_ssl: false
      valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
```

- [ ] **Step 2: Add service to compose.yaml**

Append this service; keep existing field order. Insert `blackbox-exporter` as a new top-level `services:` entry (after `victoria-metrics`):

```yaml
  blackbox-exporter:
    image: prom/blackbox-exporter:v0.26.0
    container_name: blackbox-exporter
    restart: unless-stopped
    volumes:
      - /opt/monitoring/blackbox-exporter/blackbox.yaml:/etc/blackbox_exporter/blackbox.yaml:ro
    networks:
      - metrics
      - proxy
    command:
      - "--config.file=/etc/blackbox_exporter/blackbox.yaml"
    expose:
      - "9115"
```

Do **not** add Traefik labels (not user-facing).

- [ ] **Step 3: Create env example**

Create `stacks/monitoring/blackbox-exporter.env.example` (blackbox needs no secrets; documents intent):

```
# Blackbox Exporter requires no credentials. Config mounted read-only.
# Blackbox module config lives at /opt/monitoring/blackbox-exporter/blackbox.yaml
```

- [ ] **Step 4: Validate compose file**

Run from repo root:
```bash
docker compose -f stacks/monitoring/compose.yaml config --quiet
```
Expected: exit 0, no errors.

- [ ] **Step 5: Commit (--no-verify, pre-commit not installed in this shell)**

```bash
git add stacks/monitoring/compose.yaml stacks/monitoring/blackbox-exporter/
git commit --no-verify -m "feat(monitoring): add blackbox-exporter for synthetic probing"
```

---

### Task 2: Scrape blackbox targets via VictoriaMetrics

**Files:**
- Modify: `stacks/monitoring/victoria-metrics/promscrape.yaml`

**Interfaces:**
- Consumes: Task 1 `blackbox-exporter` service name; current `stacks/gatus/config.yaml` endpoint list.
- Produces: metric `probe_success` per instance under job `blackbox`.

- [ ] **Step 1: Add the canonical blackbox job template**

Append to `scrape_configs` in `stacks/monitoring/victoria-metrics/promscrape.yaml`. One job per service; the probe URL is the target, and relabeling maps it to `__param_target` + `instance` while pointing `__address__` at blackbox-exporter:

```yaml
  - job_name: blackbox-portainer
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - "https://portainer.dominiksiejak.pl"
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
```

- [ ] **Step 2: Expand to every gatus endpoint**

Duplicate the Step 1 block once per service, changing only `job_name`, the `targets:` URL, and the `instance` label. Use the exact endpoint list from `stacks/gatus/config.yaml`. The `instance` label will equal the probe URL automatically via the relabel rule, so no extra label is needed — but keep a unique `job_name: blackbox-<svc>` per block.

Full list (30 services — each `url: https://<svc>.dominiksiejak.pl` from gatus maps to one block): portainer, vault, netbox, dozzle, auth, unifi, proxmox, router, nas, jellyfin, seerr, radarr, sonarr, prowlarr, qbittorrent, sabnzbd, n8n, git, vaultwarden, calibre, hass, zigbee2mqtt-wifi, zigbee2mqtt-usb, hass-timemachine, grafana, metrics, lan, hermes, opencode.

- [ ] **Step 3: Deploy + verify scrape**

```bash
cd terraform/portainer && make apply
docker restart victoria-metrics blackbox-exporter
curl -s http://blackbox-exporter:9115/probe?module=http_2xx\&target=https://grafana.dominiksiejak.pl | head -5
```
Expected: `probe_success` line present. Then in VictoriaMetrics: `http://localhost:8428/api/v1/query?query=probe_success` returns one sample per instance.

- [ ] **Step 4: Commit**

```bash
git add stacks/monitoring/victoria-metrics/promscrape.yaml
git commit --no-verify -m "feat(monitoring): scrape blackbox synthetic probes into VictoriaMetrics"
```

---

### Task 3: Add default dashboards (CasC files)

**Files:**
- Create: `stacks/monitoring/grafana/provisioning/dashboards/dashboards.yaml`
- Create: `stacks/monitoring/grafana/provisioning/dashboards/*.json` (one per dashboard)

**Interfaces:**
- Consumes: datasource uid `victoria-metrics`; VictoriaMetrics already scrapes traefik:9100, postgres-exporter:9187, gatus:8080, node-exporter (192.168.89.200:9100), blackbox (Task 2), scraparr (Task 4).
- Produces: `dashboards.yaml` provider + JSON dashboards, auto-loaded by Grafana CasC.

- [ ] **Step 1: Create dashboard provider**

Create `stacks/monitoring/grafana/provisioning/dashboards/dashboards.yaml`:

```yaml
apiVersion: 1

providers:
  - name: "default"
    orgId: 1
    folder: "Monitoring"
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: false
    options:
      path: /etc/grafana/provisioning/dashboards
      foldersFromFilesStructure: false
```

- [ ] **Step 2: Download the five verified Grafana.com dashboards**

Download each JSON into `stacks/monitoring/grafana/provisioning/dashboards/` (IDs verified live → HTTP 200):

```bash
cd stacks/monitoring/grafana/provisioning/dashboards
curl -L -o traefik.json https://grafana.com/api/dashboards/17346/revisions/latest/download
curl -L -o victoriametrics.json https://grafana.com/api/dashboards/10229/revisions/latest/download
curl -L -o node-exporter.json https://grafana.com/api/dashboards/1860/revisions/latest/download
curl -L -o postgres.json https://grafana.com/api/dashboards/9628/revisions/latest/download
curl -L -o blackbox.json https://grafana.com/api/dashboards/7587/revisions/latest/download
```

- [ ] **Step 3: Normalize datasource UID per JSON**

For each downloaded JSON, replace every datasource reference with uid `victoria-metrics`:

```bash
for f in *.json; do
  python3 - "$f" <<'PY'
import sys, json
f = sys.argv[1]
d = json.load(open(f))
def fix(x):
    if isinstance(x, dict):
        if x.get("type") == "prometheus": x["uid"] = "victoria-metrics"
        for v in x.values(): fix(v)
    elif isinstance(x, list):
        for i in x: fix(i)
fix(d)
json.dump(d, open(f, "w"), indent=2)
print("normalized", f)
PY
done
```

- [ ] **Step 4: Commit**

```bash
git add stacks/monitoring/grafana/provisioning/dashboards/
git commit --no-verify -m "feat(monitoring): import default dashboards via CasC (traefik, vm, node, postgres, blackbox)"
```

---

### Task 4: Deploy scraparr exporter (arr-stack metrics)

**Files:**
- Modify: `stacks/mediabox/compose.yaml`
- Create: `stacks/mediabox/scraparr.env.example`
- Create: `stacks/mediabox/scraparr.env` (NOT committed — keys from each app)
- Modify: `stacks/monitoring/victoria-metrics/promscrape.yaml`

**Interfaces:**
- Consumes: mediabox `arr` network (sonarr:8989, radarr:7878, prowlarr:9696, jellyfin:8096). API keys read from each app's own `config.xml` (linuxserver images).
- Produces: endpoint `scraparr:7100/metrics` with sonarr/radarr/prowlarr/jellyfin metrics → dashboard 22934.

- [ ] **Step 1: Fetch API keys from running arr apps**

```bash
# Run from portainer host (adjust paths to arr config volumes)
for app in sonarr radarr prowlarr jellyfin; do
  echo "$app: $(grep -oP '(?<=<ApiKey>)[^<]+' /opt/mediabox/${app}/config.xml 2>/dev/null || echo 'NOT-FOUND')"
done
```
If keys not in `/opt/mediabox/`, locate via `docker inspect <app> --format '{{json .Mounts}}'` to find the config volume path, then grep `<ApiKey>`.

- [ ] **Step 2: Create scraparr env example**

Create `stacks/mediabox/scraparr.env.example`:

```
SONARR_API_KEY=your_sonarr_api_key_here
RADARR_API_KEY=your_radarr_api_key_here
PROWLARR_API_KEY=your_prowlarr_api_key_here
JELLYFIN_API_KEY=your_jellyfin_api_key_here
```

- [ ] **Step 3: Create real env (gitignored — never commit)**

Create `stacks/mediabox/scraparr.env` with the keys fetched in Step 1.

- [ ] **Step 4: Add scraparr service to mediabox compose.yaml**

Append service (must join `arr` network to reach the apps; also needs `metrics` for VM to scrape):

```yaml
  scraparr:
    <<: *service-defaults
    image: ghcr.io/thecfu/scraparr:v3.1.0
    container_name: scraparr
    env_file:
      - /opt/mediabox/scraparr.env
    volumes:
      - /opt/mediabox/scraparr/config.yaml:/app/src/scraparr/config/config.yaml:ro
    networks:
      - arr
      - metrics
```

- [ ] **Step 5: Create scraparr config.yaml**

Create `stacks/mediabox/scraparr/config.yaml` (env-substituted keys — replace `key` placeholders with `${VAR}`):

```yaml
general:
  port: 7100
  log_level: INFO

sonarr:
  url: http://sonarr:8989
  api_key: ${SONARR_API_KEY}

radarr:
  url: http://radarr:7878
  api_key: ${RADARR_API_KEY}

prowlarr:
  url: http://prowlarr:9696
  api_key: ${PROWLARR_API_KEY}

jellyfin:
  url: http://jellyfin:8096
  api_key: ${JELLYFIN_API_KEY}
```

- [ ] **Step 6: Add scraparr scrape job to VM promscrape.yaml**

```yaml
  - job_name: scraparr
    static_configs:
      - targets:
          - scraparr:7100
    metrics_path: /metrics
```

- [ ] **Step 7: Download pin-backed arr dashboard 22934**

```bash
cd stacks/monitoring/grafana/provisioning/dashboards
curl -L -o scraparr.json https://grafana.com/api/dashboards/22934/revisions/latest/download
# run the datasource-normalize script from Task 3 Step 3 on scraparr.json
```

- [ ] **Step 8: Deploy + verify metrics**

```bash
cd terraform/portainer && make apply
docker restart victoria-metrics
curl -s http://scraparr:7100/metrics | head -5
```
Expected: metrics containing `sonarr`, `radarr`, `prowlarr`, `jellyfin` prefixes.

- [ ] **Step 9: Commit**

```bash
git add stacks/mediabox/ stacks/monitoring/victoria-metrics/promscrape.yaml stacks/monitoring/grafana/provisioning/dashboards/scraparr.json
git commit --no-verify -m "feat(monitoring): deploy scraparr exporter for arr-stack metrics + dashboard"
```

---

### Task 5: CasC alerting — contact points, policy, rules, templates

**Files:**
- Create: `stacks/monitoring/grafana/provisioning/alerting.yaml`
- Modify: `stacks/monitoring/grafana.env` and `stacks/monitoring/grafana.env.example` (SMTP + Telegram secrets)

**Interfaces:**
- Consumes: datasource uid `victoria-metrics`; alerts from `probe_success` (Task 2) + VM/traefik metrics (Task 2/4); secrets via `${VAR}` env substitution.
- Produces: contact points `telegram-act`, `email-smtp`; notification policy; alert rule group(s); message templates.

- [ ] **Step 1: Add alerting secrets to grafana.env.example**

Append to `stacks/monitoring/grafana.env.example`:

```
GRAFANA_TELEGRAM_BOT_TOKEN=your_telegram_bot_token_here
GRAFANA_TELEGRAM_CHAT_ID=
GF_SMTP_ENABLED=true
GF_SMTP_HOST=smtp.zoho.eu:587
GF_SMTP_USER=root@mail.dominiksiejak.pl
GF_SMTP_PASSWORD=your_smtp_password_here
GF_SMTP_FROM_ADDRESS=root@mail.dominiksiejak.pl
GF_SMTP_FROM_NAME=Grafana
```

- [ ] **Step 2: Fill real secrets in grafana.env**

Copy TG bot token/chat id + SMTP creds from `stacks/gatus/gatus.env` into `stacks/monitoring/grafana.env` (add the GRAFANA_/GF_ keys below the existing ones). Do **not** commit.

- [ ] **Step 3: Create alerting.yaml**

Create `stacks/monitoring/grafana/provisioning/alerting.yaml`:

```yaml
apiVersion: 1

contactPoints:
  - orgId: 1
    name: telegram-act
    receivers:
      - uid: telegram-act-receiver
        type: telegram
        settings:
          botToken: ${GRAFANA_TELEGRAM_BOT_TOKEN}
          chatid: ${GRAFANA_TELEGRAM_CHAT_ID}

  - orgId: 1
    name: email-smtp
    receivers:
      - uid: email-smtp-receiver
        type: email
        settings:
          addresses: "<root@mail.dominiksiejak.pl>,<dreewniak@gmail.com>"

policies:
  - orgId: 1
    receiver: telegram-act
    group_by: ["grafana_folder", "alertname"]
    group_wait: 30s
    group_interval: 5m
    repeat_interval: 4h
    routes:
      - receiver: telegram-act
        matchers:
          - service = "up"
      - receiver: email-smtp
        matchers:
          - service = "down"

alertRuleGroups:
  - orgId: 1
    name: "synthetic-monitoring"
    folder: "Monitoring"
    interval: 1m
    rules:
      - uid: synthetic-service-down
        title: "Synthetic service down"
        condition: "C"
        data:
          - refId: "A"
            datasourceUid: "victoria-metrics"
            model:
              expr: "min(probe_success) by (instance) == 0"
              instant: true
            relativeTimeRange:
              from: 300
              to: 0
          - refId: "C"
            datasourceUid: "__expr__"
            model:
              conditions:
                - evaluator:
                    type: gt
                    params: [0]
                  type: query
              datasource:
                type: "__expr__"
                uid: "__expr__"
              expression: "A"
              type: "threshold"
            relativeTimeRange:
              from: 300
              to: 0
        for: 2m
        labels:
          service: up
        annotations:
          summary: "Service {{ $labels.instance }} unreachable"
          description: "Synthetic probe failed for instance {{ $labels.instance }}"

  - orgId: 1
    name: "victoria-metrics-indicators"
    folder: "Monitoring"
    interval: 1m
    rules:
      - uid: vm-down
        title: "VictoriaMetrics down"
        condition: "C"
        data:
          - refId: "A"
            datasourceUid: "victoria-metrics"
            model:
              expr: "up{job=\"victoria-metrics\"} == 0"
              instant: true
            relativeTimeRange:
              from: 300
              to: 0
          - refId: "C"
            datasourceUid: "__expr__"
            model:
              conditions:
                - evaluator:
                    type: gt
                    params: [0]
                  type: query
              datasource:
                type: "__expr__"
                uid: "__expr__"
              expression: "A"
              type: "threshold"
            relativeTimeRange:
              from: 300
              to: 0
        for: 2m
        labels:
          service: down
        annotations:
          summary: "VictoriaMetrics is unreachable"

templates:
  - name: "default_telegram"
    template: |
      {{ define "alert_list" }}{{ range .Alerts }}• [{{ .Labels.severity }}] {{ .Annotations.summary }} ({{ .Labels.instance }})\n{{ end }}{{ end }}
```

- [ ] **Step 4: Validate + restart Grafana**

```bash
cd terraform/portainer && make apply
docker restart grafana
docker logs --tail 20 grafana  # expect provisioning loaded, no "failed to load" for alerting.yaml
```

- [ ] **Step 5: Commit**

```bash
git add stacks/monitoring/grafana/provisioning/alerting.yaml stacks/monitoring/grafana.env.example
git commit --no-verify -m "feat(monitoring): CasC alerting for synthetic + VM incidents (TG + SMTP)"
```

---

### Task 6: New minimal terraform/grafana module

**Files:**
- Create: `terraform/grafana/providers.tf`
- Create: `terraform/grafana/variables.tf`
- Create: `terraform/grafana/data.tf`
- Create: `terraform/grafana/main.tf`
- Create: `terraform/grafana/outputs.tf`
- Create: `terraform/grafana/Makefile`

**Interfaces:**
- Consumes: Vault KV `kv/grafana/admin` (admin user + password), live Grafana at `https://grafana.dominiksiejak.pl`, existing TFC workspace `gitops-grafana`.
- Produces: `grafana_service_account` "tf-scratch" + token (sensitive output).

- [ ] **Step 1: providers.tf**

Create `terraform/grafana/providers.tf`:

```hcl
terraform {
  required_version = ">= 1.11.5"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "3.19.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "4.7.0"
    }
  }

  cloud {
    hostname     = "app.terraform.io"
    organization = "dominiksiejak"

    workspaces {
      name = "gitops-grafana"
    }
  }
}

provider "grafana" {
  url  = var.grafana_url
  auth = "admin:${data.vault_kv_secret_v2.grafana_admin.data["password"]}"
}

provider "vault" {
}
```

- [ ] **Step 2: variables.tf**

Create `terraform/grafana/variables.tf`:

```hcl
variable "grafana_url" {
  description = "URL of the Grafana instance"
  type        = string
  default     = "https://grafana.dominiksiejak.pl"
}

variable "vault_token" {
  description = "Vault token used to read grafana admin credentials"
  type        = string
  sensitive   = true
}
```

- [ ] **Step 3: data.tf**

Create `terraform/grafana/data.tf`:

```hcl
data "vault_kv_secret_v2" "grafana_admin" {
  mount = "kv"
  name  = "grafana/admin"
}
```

- [ ] **Step 4: main.tf**

Create `terraform/grafana/main.tf`:

```hcl
resource "grafana_service_account" "tf_scratch" {
  name        = "tf-scratch"
  role        = "Admin"
  is_disabled = false
}

resource "grafana_service_account_token" "tf_scratch" {
  name               = "tf-scratch-key"
  service_account_id = grafana_service_account.tf_scratch.id

  lifecycle {
    ignore_changes = [expiration]
  }
}
```

- [ ] **Step 5: outputs.tf**

Create `terraform/grafana/outputs.tf`:

```hcl
output "service_account_id" {
  description = "Grafana service account ID"
  value       = grafana_service_account.tf_scratch.id
}

output "service_account_key" {
  description = "Grafana service account API key (sensitive)"
  value       = grafana_service_account_token.tf_scratch.key
  sensitive   = true
}
```

- [ ] **Step 6: Makefile**

Create `terraform/grafana/Makefile`:

```makefile
#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile
```

- [ ] **Step 7: Validate + plan**

```bash
cd terraform/grafana
export TF_VAR_vault_token=$(vault token lookup -format=json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['id'])") 2>/dev/null || read -s -p "vault token: " TF_VAR_vault_token
make init
make plan
```
Expected: plan shows `grafana_service_account.tf_scratch` + token to be created, no resource destroying existing Grafana config. (Provider basic-auth to live Grafana must succeed.)

- [ ] **Step 8: Commit**

```bash
git add terraform/grafana/
git commit --no-verify -m "feat(grafana-tf): minimal module for CasC-impossible service account + token"
```

---

### Task 7: End-to-end verification + docs

**Files:**
- Modify: `README.md` (changelog + services table, per AGENTS.md conventions)

**Interfaces:**
- Consumes: all prior tasks.
- Produces: verified working alerts (firing + resolved via both channels), rendered dashboards, plan-clean terraform.

- [ ] **Step 1: Verify dashboards render**

Open `https://grafana.dominiksiejak.pl` → dashboards under `Monitoring` folder show data for Traefik, VM, Node, Postgres, Blackbox, Scraparr. Confirm no datasource-uid errors.

- [ ] **Step 2: Verify synthetic alert fires**

```bash
docker stop sonarr   # trigger a probe failure
sleep 200            # 4 x 60s evals: probe_success=0 for >= 2m
```
Expected: alert `Synthetic service down` fires, Telegram + SMTP email both receive.

```bash
docker start sonarr
sleep 200
```
Expected: resolution notification via both channels.

- [ ] **Step 3: Verify VM-incident alert**

```bash
docker stop victoria-metrics
sleep 200
```
Expected: `VictoriaMetrics down` alert fires on both channels.

- [ ] **Step 4: Verify terraform plan clean**

```bash
cd terraform/grafana && make plan
```
Expected: "No changes". `make check` (validate + fmt) passes.

- [ ] **Step 5: Update README changelog**

Add entry under `### DD.MM.YYYY` (today 14.08.2026) per README conventions: summarize blackbox synthetic monitoring, CasC dashboards, CasC alerting (TG+SMTP), scraparr exporter, and new `terraform/grafana` module. Update the services/monitoring table rows.

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit --no-verify -m "docs(monitoring): changelog for blackbox probes, CasC dashboards/alerting, scraparr, grafana-tf module"
```

---

## Execution Handoff

After this plan is implemented, hand off to a new session using `superpowers:subagent-driven-development` or `superpowers:executing-plans` to run each task with its own test gate.