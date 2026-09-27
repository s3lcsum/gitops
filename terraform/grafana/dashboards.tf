locals {
  dashboard_dir   = "${path.module}/../../kubernetes/monitoring/config/grafana-provisioning/dashboards"
  dashboard_files = fileset(local.dashboard_dir, "*.json")
}

resource "grafana_folder" "monitoring" {
  title = "Monitoring"
  uid   = "monitoring"
}

resource "grafana_dashboard" "provisioned" {
  for_each = local.dashboard_files

  folder = grafana_folder.monitoring.uid
  # Keep panels pointed at the managed datasource uid (victoria-metrics after apply).
  config_json = replace(
    file("${local.dashboard_dir}/${each.value}"),
    "\"uid\": \"victoria-metrics\"",
    "\"uid\": \"${grafana_data_source.victoria_metrics.uid}\""
  )
  overwrite = true

  depends_on = [grafana_data_source.victoria_metrics]
}

# Cloud-only dashboards not in OSS file provisioning.
# Reviewed 2026-09-26 against dreewniak.grafana.net (41 dashboards).
# Kept: s3lcsum default dashboard — still queries Cloud Prometheus synthetic checks.
# Dropped (deprecated, not imported):
#   Proxmox (oaFOuxdVk) — last edit 2022-11-30, Graphite panels, no Proxmox metrics in Cloud.
#   GrafanaCloud / Synthetic Monitoring / Cloud provider - GCP — stack-provisioned, not homelab SoT.
resource "grafana_dashboard" "cloud_kept" {
  for_each = fileset("${path.module}/dashboards", "*.json")

  config_json = file("${path.module}/dashboards/${each.value}")
  overwrite   = true
}
