# Synology NAS SNMP Monitoring Design

**Date:** 2026-08-16
**Status:** Approved (pending spec review)

## Goal

Expose full system metrics from the Synology NAS (`192.168.89.240`, DSM web
`:5001`, publicly `nas.dominiksiejak.pl`) in Grafana, alongside the existing
VictoriaMetrics + blackbox monitoring already in place.

Today the NAS is only covered by an HTTP blackbox probe (uptime). This change
adds deep SNMP metrics: CPU load, RAM, disk/volume usage, per-bay SMART +
temperature, fans, interface throughput, and uptime — scraped into VictoriaMetrics
and shown via a provisioned Grafana dashboard.

## Approach

**Option A: Prometheus `snmp-exporter` + Synology seed + provisioned dashboard.**

- Prometheus's `snmp-exporter` walks the NAS over SNMPv3 (user + SHA auth + AES
  privacy).
- The exporter is configured with the Synology seed module (`synology`), which
  maps DSM MIB OIDs into `synology_*` series.
- VictoriaMetrics scrapes `snmp-exporter:9116/snmp?target=...&module=synology`.
- A community "Synology DiskStation" dashboard is delivered declaratively via
  Grafana file provisioning.

Rejected alternatives: DIY hand-written OID probes (more toil, reinvents the
wheel), and DSM API/SSH polling (fragile auth, vendor-specific).

## Architecture & Data Flow

```
Synology NAS 192.168.89.240:161/udp (SNMPv3)
   ^ walks
prom/snmp-exporter:9116  (config: /opt/monitoring/snmp-exporter/synology.yml)
   ^ scrapes via VictoriaMetrics promscrape job "synology"
victoria-metrics (metrics network)
   ^ queries
grafana  (dashboard "Synology DiskStation", VictoriaMetrics datasource)
```

All three collector/UI services already exist in `stacks/monitoring/`; only
`snmp-exporter` is new.

## Components

### 1. DSM side (enable SNMPv3)
In DSM Control Panel → SNMP:
- Enable **SNMPv3** with a dedicated user:
  - Username (e.g. `snmp_grafana`), **auth protocol SHA** + auth passphrase,
    **privacy protocol AES** + privacy passphrase.
- Service name `SynologyNAS`, optional Location/Contact.
- Port: UDP 161 (default).
- Verify from the host before wiring the exporter:
  `snmpwalk -v3 -l authPriv -u <user> -a SHA -A <auth> -X <priv> 192.168.89.240 system`

### 2. `stacks/monitoring/compose.yaml` — add snmp-exporter service
Field order per repo convention (`image`, `container_name`, `restart`, etc.):

```yaml
  snmp-exporter:
    image: prom/snmp-exporter:v0.28.0
    container_name: snmp-exporter
    restart: unless-stopped
    volumes:
      - /opt/monitoring/snmp-exporter/synology.yml:/etc/snmp_exporter/synology.yml:ro
    networks:
      - metrics
      - proxy
    command:
      - "--config.file=/etc/snmp_exporter/synology.yml"
    expose:
      - "9116"
```

### 3. `snmp-exporter/synology.yml` (generated seed, secrets handled)
Volume of concern: snmp-exporter keeps SNMPv3 credentials inside the module's
`auth` block in its config YAML. AGENTS forbids committing secrets.

- Commit **`synology.yml.example`** — the generator output with `username`,
  auth, and privacy values replaced by placeholders.
- The **real `synology.yml`** lives at `/opt/monitoring/snmp-exporter/`
  (gitignored; add a `.gitignore` rule, see below) populated with the actual
  v3 user / SHA auth pass / AES priv pass.
- Compose mounts the real file read-only.

### 4. `victoria-metrics/promscrape.yaml` — add synology job

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
```

(Note: v3 credentials are NOT passed as a query `auth` param — they are read from
the exporter module config. The v2c `auth: [public]` param is only needed for the
community-string path, which we are not using.)

### 5. Grafana dashboard — `grafana/provisioning/dashboards/synology.json`
- Import the community **"Synology DiskStation"** dashboard (Grafana dash ID
  ~`12034`).
- The existing file provider (`dashboards.yaml`) auto-loads any JSON in
  `/etc/grafana/provisioning/dashboards` with `updateIntervalSeconds: 30`, so a
  committed `synology.json` provisions declaratively and reproduces on rebuild.
- Datasource: the already-provisioned VictoriaMetrics datasource.

### 6. `.gitignore`
Add a rule so the populated secret file is never committed:

```
stacks/monitoring/snmp-exporter/synology.yml
```

## Error Handling

- **SNMP auth failure** → exporter returns no series; VictoriaMetrics target
  shows down. Diagnose via `snmpwalk` from the host + exporter logs.
- **Config mount**: Portainer does not hot-reload file-provisioned configs —
  `snmp-exporter` and `victoria-metrics` are restarted after `make apply`
  (matches the existing apply-portainer workflow for volume-mounted configs).
- **Missing dashboard data** → confirm `synology_*` series exist in
  VictoriaMetrics before wiring dashboard panels; if the seed omits an OID,
  extend the module.

## Testing / Verification

1. DSM: enable SNMPv3, run `snmpwalk` from host → returns `system` tree.
2. `snmp-exporter` container up; `curl snmp-exporter:9116/snmp?target=192.168.89.240&module=synology`
   returns `synology_*` series (do this inside `metrics` network).
3. VictoriaMetrics target `synology` = UP; `synology_*` series present.
4. Grafana dashboard loads and panels populate from VictoriaMetrics.

## Deployment (AGENTS workflow)

1. `pre-commit run --all-files`
2. `make apply` in `terraform/portainer/` (syncs `stacks/monitoring` to the
   host, recreates containers)
3. Restart `snmp-exporter` + `victoria-metrics` (config mounts not hot-reloaded)
4. Verify per Testing above.

## Out of Scope

- Alerts on NAS metrics (can be added later to `alerting.yaml`).
- Collecting SNMP from any other device.
- DSM password/API integration.
