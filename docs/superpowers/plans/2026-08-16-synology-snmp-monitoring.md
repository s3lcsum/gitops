# Synology NAS SNMP Monitoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an SNMP exporter that scrapes full Synology NAS metrics into VictoriaMetrics and shows them on a provisioned Grafana dashboard.

**Architecture:** Add a `snmp-exporter` service to the existing `monitoring` Docker Compose stack. It walks the NAS over SNMPv3 using the Synology seed module, exposing `synology_*` metrics. VictoriaMetrics scrapes the exporter's `/snmp` endpoint; a provisioned Grafana dashboard visualizes the series from the existing VictoriaMetrics datasource.

**Tech Stack:** Prometheus `snmp-exporter` v0.28.0, VictoriaMetrics (existing), Grafana file provisioning, Docker Compose, plain YAML.

## Global Constraints

- Follow the repo's Compose field order: `image`, `container_name`, `restart`, `env_file`, `environment`, `volumes`, `networks`, `ports`, `user`, `healthcheck`, `labels`.
- Use `/opt/<stack>/<service>.env` (host path) for env files; never relative `env_file:` paths.
- **Never commit secrets.** The NAS SNMPv3 credentials live in a gitignored `synology.yml` on disk (rsync copies it to the host). Commit only `synology.yml.example` with placeholders.
- Existing `dashboards.yaml` file-provisioning auto-loads any JSON in `/etc/grafana/provisioning/dashboards` (update interval 30s). Drop a `.json` there.
- Deploy via `make apply` in `terraform/portainer/` (rsyncs `stacks/` → `portainer:/opt`, recreates containers). Then manually restart `snmp-exporter` + `victoria-metrics` (file-provisioned configs are not hot-reloaded).
- Tesla run `tofu fmt` / `tofu validate` after HCL edits (none in this plan).
- NAS IP: `192.168.89.240`. SNMPv3: user, auth SHA, priv AES. Port UDP 161.
- Use `tofu`, not `terraform`.

---

### Task 1: Enable SNMPv3 on the NAS (DSM)

**Files:** none (manual, on the NAS)

**Interfaces:**
- Produces: an SNMPv3 user + credentials the exporter auth block will use:
  `SNMP_V3_USER`, `SNMP_AUTH_PASS`, `SNMP_PRIV_PASS`.

- [ ] **Step 1: Enable SNMP on DSM**

  Open DSM → **Control Panel → SNMP**. Enable **SNMPv3**. Create a user with:
  - **Username:** `snmp_grafana` (or your choice)
  - **Auth protocol:** SHA, with a strong **auth passphrase**
  - **Privacy protocol:** AES, with a strong **privacy passphrase**
  - Service name: `SynologyNAS`

  Confirm your chosen values match what you'll put in `synology.yml`.

- [ ] **Step 2: Sanity-check SNMPv3 from the host**

  Run (substituting your credentials):

  ```bash
  snmpwalk -v3 -l authPriv -u snmp_grafana -a SHA -A YOUR_AUTH_PASS -x AES -X YOUR_PRIV_PASS 192.168.89.240 system
  ```

  Expected: a `SNMPv2-MIB::system.*` tree (hostname, uptime, description).
  If it fails, re-check version (`-v3`), security level `authPriv`, and that
  the SNMP service is running on the NAS.

- [ ] **Step 3: Note the credentials for later**

  Record `SNMP_V3_USER`, `SNMP_AUTH_PASS`, `SNMP_PRIV_PASS` for Task 2. Never
  commit them.

---

### Task 2: Generate the `synology` module config (real, gitignored)

**Files:**
- Create: `stacks/monitoring/snmp-exporter/synology.yml` (gitignored, on disk so rsync ships it)

**Interfaces:**
- Consumes: `SNMP_V3_USER`, `SNMP_AUTH_PASS`, `SNMP_PRIV_PASS` (Task 1)
- Produces: `synology.yml` — an snmp-exporter config containing a `synology`
  module with `auth` set to the SNMPv3 user and a `version: 3` auth block.
  Task 3 will copy this into a committed `.example`.

- [ ] **Step 1: Create the snmp-exporter config directory**

  ```bash
  mkdir -p stacks/monitoring/snmp-exporter
  ```

- [ ] **Step 2: Obtain a Synology snmp-exporter config**

  Grab the maintained Synology seed config from the community
  `chillsam/synology.snmp` (or generate it yourself with `snmp-generator` if
  you prefer). A known-good URL:

  ```bash
  curl -fsSL -o stacks/monitoring/snmp-exporter/synology.yml \
    https://raw.githubusercontent.com/chillsam/synology.snmp/master/synology.yml
  ```

  Verify it is a valid snmp-exporter config (has a top-level `auths:` and a
  `synology` key, typically under `modules:` or via a top-level `# WARNING` /
  `hash_mod` generated structure):

  ```bash
  wc -l stacks/monitoring/snmp-exporter/synology.yml
  grep -c "synology" stacks/monitoring/snmp-exporter/synology.yml
  ```

  Expected: a multi-hundred-line YAML; `synology` appears in the module/section
  headers.

- [ ] **Step 3: Inject the SNMPv3 auth block**

  The exact auth placement depends on the config you downloaded. For a
  generator-style config that defines the module inside a top-level
  `modules:` map, add a `synology` module entry pointing at the auth and the
  OID walk. If the downloaded file already ships the module and only needs the
  credentials, set `version: 3`, `username`, `auth_protocol: SHA`,
  `auth_password`, `priv_protocol: AES`, `priv_password` in the module's
  auth block. Example module fragment (structure must match your generator
  version):

  ```yaml
  auths:
    public:
      version: 3
      security_level: authPriv
      username: SNMP_V3_USER
      auth_protocol: SHA
      auth_password: SNMP_AUTH_PASS
      priv_protocol: AES
      priv_password: SNMP_PRIV_PASS
  ```

  Confirm the wire format for snmp-exporter v0.28.0 — the auth is defined once
  per snmp auth name, and the `target` is passed via the `/snmp` query.

- [ ] **Step 4: Validate the config loads**

  Start a throwaway exporter to confirm the config parses:

  ```bash
  docker run --rm -it \
    -v "$PWD/stacks/monitoring/snmp-exporter/synology.yml:/etc/snmp_exporter/config.yml:ro" \
    prom/snmp-exporter:v0.28.0 --config.file=/etc/snmp_exporter/config.yml
  ```

  Expected: the exporter starts without a config parse error (log shows
  "Starting SNMP exporter"). Ctrl-C to stop.

---

### Task 3: Commit the `.example` with placeholders

**Files:**
- Create: `stacks/monitoring/snmp-exporter/synology.yml.example`

**Interfaces:**
- Consumes: `synology.yml` (Task 2)
- Produces: `synology.yml.example` — committed template with credentials (and
  any password fields) replaced by placeholders.

- [ ] **Step 1: Copy the real config to `.example` and strip secrets**

  ```bash
  cd stacks/monitoring/snmp-exporter
  cp synology.yml synology.yml.example
  # Replace username + both passphrases with placeholders, e.g.:
  #   username: <SNMP_USER>
  #   auth_password: <SNMP_AUTH_PASS>
  #   priv_password: <SNMP_PRIV_PASS>
  ```

  Do this by hand in an editor — replace exactly the SNMPv3 username, the auth
  password, and the privacy password you set in Task 1. Leave everything else
  intact, including the coalesced OID walk.

- [ ] **Step 2: Commit the `.example`**

  ```bash
  git add stacks/monitoring/snmp-exporter/synology.yml.example
  git commit -m "chore(monitoring): add snmp-exporter synology config template"
  ```

  The real `synology.yml` must remain untracked/gitignored (covered in Task 4).

---

### Task 4: Gitignore the real `synology.yml`

**Files:**
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing
- Produces: a rule ensuring `stacks/monitoring/snmp-exporter/synology.yml` is
  never committed.

- [ ] **Step 1: Add the ignore rule**

  Append to `.gitignore`:

  ```
  # Real snmp-exporter config with NAS SNMPv3 credentials
  stacks/monitoring/snmp-exporter/synology.yml
  ```

- [ ] **Step 2: Verify it's ignored**

  ```bash
  git status --porcelain
  git check-ignore stacks/monitoring/snmp-exporter/synology.yml
  ```

  Expected: `synology.yml` is not listed as untracked; `git check-ignore`
  prints the path. `synology.yml.example` IS tracked.

- [ ] **Step 3: Commit**

  ```bash
  git add .gitignore
  git commit -m "chore: gitignore real snmp-exporter synology config"
  ```

---

### Task 5: Add the `snmp-exporter` service to the monitoring stack

**Files:**
- Modify: `stacks/monitoring/compose.yaml`

**Interfaces:**
- Consumes: the mounted `synology.yml` config path (Task 2/4)
- Produces: a running `snmp-exporter` container on `metrics` + `proxy`, exposed
  on `9116`, reachable inside the Docker network as `snmp-exporter:9116`.

- [ ] **Step 1: Add the service block**

  Append to `stacks/monitoring/compose.yaml` (after `blackbox-exporter`,
  before the `networks:` section):

  ```yaml
  snmp-exporter:
    image: prom/snmp-exporter:v0.28.0
    container_name: snmp-exporter
    restart: unless-stopped
    volumes:
      - /opt/monitoring/snmp-exporter/synology.yml:/etc/snmp_exporter/config.yml:ro
    networks:
      - metrics
      - proxy
    command:
      - "--config.file=/etc/snmp_exporter/config.yml"
    expose:
      - "9116"
  ```

  Note the mount source `/opt/monitoring/snmp-exporter/synology.yml` matches
  the rsync-destination path (rsync puts `stacks/monitoring/snmp-exporter/...`
  at `/opt/monitoring/snmp-exporter/...`).

- [ ] **Step 2: Commit**

  ```bash
  git add stacks/monitoring/compose.yaml
  git commit -m "feat(monitoring): add snmp-exporter service for Synology NAS"
  ```

---

### Task 6: Add the `synology` scrape job to VictoriaMetrics

**Files:**
- Modify: `stacks/monitoring/victoria-metrics/promscrape.yaml`

**Interfaces:**
- Consumes: the `snmp-exporter` service DNS name `snmp-exporter:9116` (Task 5)
- Produces: a VM scrape job named `synology` targeting the NAS via the exporter.

- [ ] **Step 1: Add the scrape job**

  Append to `stacks/monitoring/victoria-metrics/promscrape.yaml` (anywhere after
  the existing scraping jobs):

  ```yaml
  - job_name: synology
    static_configs:
      - targets:
          - "192.168.89.240"
    params:
      module: [synology]
    metrics_path: /snmp
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: snmp-exporter:9116
    scrape_interval: 60s
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add stacks/monitoring/victoria-metrics/promscrape.yaml
  git commit -m "feat(monitoring): scrape Synology NAS via snmp-exporter"
  ```

---

### Task 7: Add the Grafana Synology dashboard (provisioned)

**Files:**
- Create: `stacks/monitoring/grafana/provisioning/dashboards/synology.json`

**Interfaces:**
- Consumes: `synology_*` series in VictoriaMetrics (Task 6), the VictoriaMetrics
  datasource (already provisioned), and the file provisioning provider in
  `dashboards.yaml` (already present).
- Produces: a dashboard that auto-loads into Grafana.

- [ ] **Step 1: Download the community dashboard JSON**

  Grab the "Synology DiskStation" dashboard (ID **12034**):

  ```bash
  curl -fsSL -o stacks/monitoring/grafana/provisioning/dashboards/synology.json \
    "https://grafana.com/api/dashboards/12034/revisions/latest/download"
  ```

  (If 12034 is unavailable/deprecated, pick the current Synology dashboard and
  use its ID — note the chosen ID in the commit.)

- [ ] **Step 2: Point the dashboard at the VictoriaMetrics datasource**

  In `synology.json`, the datasource UID must equal the provisioned
  VictoriaMetrics datasource UID. Inspect the existing
  `grafana/provisioning/datasources/victoria-metrics.yaml` to get the `uid`,
  then patch every `"datasource"` / `"uid"` in `synology.json` that references
  an old datasource to that UID (or set to `"${DS_PROMETHEUS}"` if the
  datasource import pattern uses variables). Confirm with:

  ```bash
  grep -n '"datasource"\|"uid"' stacks/monitoring/grafana/provisioning/dashboards/synology.json | head
  ```

- [ ] **Step 3: Validate the JSON**

  ```bash
  python3 -m json.tool stacks/monitoring/grafana/provisioning/dashboards/synology.json > /dev/null && echo "valid JSON"
  ```

  Expected: `valid JSON`.

- [ ] **Step 4: Commit**

  ```bash
  git add stacks/monitoring/grafana/provisioning/dashboards/synology.json
  git commit -m "feat(monitoring): add Synology DiskStation Grafana dashboard"
  ```

---

### Task 8: Deploy and verify end-to-end

**Files:** none (deploy/verify)

**Interfaces:**
- Consumes: all commits from Tasks 3-7 (configs on disk), NAS SNMPv3 from Task 1.

- [ ] **Step 1: Run pre-commit**

  ```bash
  pre-commit run --all-files
  ```

  Expected: all hooks pass (note: if any JSON/YAML were reformatted by
  end-of-file fixer, re-add and commit those before continuing).

- [ ] **Step 2: Deploy the stack via Portainer**

  ```bash
  cd terraform/portainer && make apply
  ```

  This rsyncs `stacks/` to `portainer:/opt` and recreates the monitoring
  compose stack on the host (including the new `snmp-exporter`).

- [ ] **Step 3: Restart the config-provisioned containers**

  The new `snmp-exporter` starts fresh, but VictoriaMetrics' scrape config is
  a file mount Portainer won't hot-reload — so restart both:

  ```bash
  ssh portainer 'docker restart snmp-exporter victoria-metrics'
  ```

- [ ] **Step 4: Verify the exporter answers**

  Query the exporter directly inside the `metrics` network:

  ```bash
  ssh portainer 'docker run --rm --network metrics curlimages/curl -s \
    "http://snmp-exporter:9116/snmp?target=192.168.89.240&module=synology" | head'
  ```

  Expected: a Prometheus text exposition stream containing `synology_*` series.
  If empty, check snmp-exporter logs:
  `ssh portainer 'docker logs snmp-exporter --tail 50'`.

- [ ] **Step 5: Verify VictoriaMetrics scrapes it**

  Check the target in VictoriaMetrics:

  ```bash
  curl -s 'http://metrics.dominiksiejak.pl/api/v1/targets' | grep -A2 synology
  ```

  Expected: `"health":"up"`. Then confirm series exist:

  ```bash
  curl -s 'http://metrics.dominiksiejak.pl/api/v1/label/synology_*' | head
  ```

- [ ] **Step 6: Verify the Grafana dashboard**

  Load https://grafana.dominiksiejak.pl, open the **Synology DiskStation**
  dashboard in the **Monitoring** folder. Confirm panels populate (CPU, RAM,
  volumes, disks, temps, fans, interfaces) from VictoriaMetrics. If panels are
  empty, check the Query Inspector datasource is VictoriaMetrics and the
  `synology_*` series match the dashboard's metric filters (adjust the
  dashboard's metric names or instance label if the seed differs).

- [ ] **Step 7: Commit any final repo fixes**

  If Task 8's verification exposed config drift (e.g. dashboard datasource UID
  fixups), commit them:

  ```bash
  git add -A
  git commit -m "fix(monitoring): finalize Synology SNMP dashboard and config"
  ```

---

## Self-Review

**Spec coverage:**
- DSM SNMPv3 enable + `snmpwalk` sanity → Task 1 ✓
- Add `snmp-exporter` service to compose → Task 5 ✓ (matches spec's example)
- `synology.yml` generator output, secrets handled (gitignored real file +
  committed `.example`) → Tasks 2-3-4 ✓
- VictoriaMetrics scrape job → Task 6 ✓
- Grafana dashboard provisioned → Task 7 ✓
- `.gitignore` rule → Task 4 ✓
- Deploy + verify (pre-commit, make apply, restart, target up, series present,
  dashboard populates) → Task 8 ✓

**Placeholder scan:** No "TBD"/further-work markers; every step has concrete
commands/expectations. The `SNMP_*` names are concrete Task-1 outputs, not
placeholders.

**Type/index consistency:** `snmp-exporter:9116`, module `synology`, NAS IP
`192.168.89.240`, config mount `/opt/monitoring/snmp-exporter/synology.yml`
(rsync destination of `stacks/monitoring/snmp-exporter/synology.yml`) are
consistent across Tasks 2-6. The exporter command uses `config.yml` as the
internal mount target in both service def and validation runs (Task 2 Step 4,
Task 5 Step 1) — kept consistent.
