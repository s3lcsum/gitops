output "victoria_metrics_datasource_uid" {
  description = "UID of the PDC-backed VictoriaMetrics datasource"
  value       = grafana_data_source.victoria_metrics.uid
}

output "loki_datasource_uid" {
  description = "UID of the PDC-backed Loki datasource"
  value       = grafana_data_source.loki.uid
}

output "irm_integration_link" {
  description = "HTTP endpoint for the homelab Grafana Alerting → IRM integration"
  value       = grafana_oncall_integration.homelab.link
  sensitive   = true
}

output "terrakube_drift_oncall_webhook_url" {
  description = "Grafana OnCall formatted_webhook URL for Terrakube drift-enforce alerts"
  value       = grafana_oncall_integration.terrakube_drift.link
  sensitive   = true
}

output "monitoring_folder_uid" {
  description = "UID of the Monitoring root folder (alert rules + nested dashboard categories)"
  value       = grafana_folder.monitoring.uid
}
