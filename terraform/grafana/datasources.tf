# Live Cloud datasource uid is victoria-metrics (PDC HomeLab).
# Created via API because Grafana rejects uid changes on an existing datasource.
# Do not import afzgefwo6esxsa — that leftover cannot be deleted with the MCP token.

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

# In-cluster Loki (Alloy → loki.monitoring.svc). PDC agent runs in monitoring ns.
# Agent PermitRemoteOpen must include loki:3100 (see kubernetes/monitoring/resources/grafana-pdc-agent.yaml).
resource "grafana_data_source" "loki" {
  type                                   = "loki"
  name                                   = "Loki"
  uid                                    = "loki"
  url                                    = var.loki_url
  access_mode                            = "proxy"
  private_data_source_connect_network_id = var.pdc_network_id

  json_data_encoded = jsonencode({
    maxLines = 1000
  })
}
