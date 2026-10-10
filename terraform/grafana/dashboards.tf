locals {
  dashboard_dir = "${path.module}/dashboards"
  # Paths relative to dashboards/, e.g. "kubernetes/k8s-overview.json"
  dashboard_files = fileset(local.dashboard_dir, "**/*.json")

  # Subdir name → Grafana folder title
  dashboard_folder_titles = {
    overview   = "Overview"
    kubernetes = "Kubernetes"
    network    = "Network"
    apps       = "Apps"
  }

  dashboard_categories = toset([
    for f in local.dashboard_files : dirname(f)
    if dirname(f) != "." && contains(keys(local.dashboard_folder_titles), dirname(f))
  ])
}

resource "grafana_folder" "monitoring" {
  title = "Monitoring"
  uid   = "monitoring"
}

resource "grafana_folder" "category" {
  for_each = local.dashboard_categories

  title             = local.dashboard_folder_titles[each.value]
  uid               = "monitoring-${each.value}"
  parent_folder_uid = grafana_folder.monitoring.uid
}

resource "grafana_dashboard" "provisioned" {
  for_each = local.dashboard_files

  folder = (
    dirname(each.value) == "."
    ? grafana_folder.monitoring.uid
    : grafana_folder.category[dirname(each.value)].uid
  )
  config_json = replace(
    file("${local.dashboard_dir}/${each.value}"),
    "\"uid\": \"victoria-metrics\"",
    "\"uid\": \"${grafana_data_source.victoria_metrics.uid}\""
  )
  overwrite = true

  depends_on = [
    grafana_data_source.victoria_metrics,
    grafana_folder.category,
  ]
}
