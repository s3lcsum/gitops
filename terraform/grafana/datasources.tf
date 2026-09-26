# Import existing UI connector (PDC HomeLab already bound):
#   tofu import 'grafana_data_source.victoria_metrics' afzgefwo6esxsa
# Apply then rewrites uid → victoria-metrics (matches OSS dashboard JSON).

resource "grafana_data_source" "victoria_metrics" {
  type                                   = "victoriametrics-metrics-datasource"
  name                                   = "VictoriaMetrics"
  uid                                    = "victoria-metrics"
  url                                    = var.victoria_metrics_url
  access_mode                            = "proxy"
  is_default                             = true
  private_data_source_connect_network_id = var.pdc_network_id

  json_data_encoded = jsonencode({
    httpMethod = "POST"
  })
}
