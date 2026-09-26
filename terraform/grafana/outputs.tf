output "victoria_metrics_datasource_uid" {
  description = "UID of the PDC-backed VictoriaMetrics datasource"
  value       = grafana_data_source.victoria_metrics.uid
}

output "irm_integration_link" {
  description = "HTTP endpoint for the homelab Alertmanager → IRM integration"
  value       = grafana_oncall_integration.homelab.link
  sensitive   = true
}

output "monitoring_folder_uid" {
  description = "UID of the Monitoring folder in Grafana Cloud"
  value       = grafana_folder.monitoring.uid
}
