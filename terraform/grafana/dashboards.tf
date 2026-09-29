locals {
  dashboard_dir   = "${path.module}/dashboards"
  dashboard_files = fileset(local.dashboard_dir, "*.json")
}

resource "grafana_folder" "monitoring" {
  title = "Monitoring"
  uid   = "monitoring"
}

resource "grafana_dashboard" "provisioned" {
  for_each = local.dashboard_files

  folder = grafana_folder.monitoring.uid
  config_json = replace(
    file("${local.dashboard_dir}/${each.value}"),
    "\"uid\": \"victoria-metrics\"",
    "\"uid\": \"${grafana_data_source.victoria_metrics.uid}\""
  )
  overwrite = true

  depends_on = [grafana_data_source.victoria_metrics]
}
