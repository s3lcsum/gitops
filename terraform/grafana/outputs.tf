output "service_account_id" {
  description = "Grafana service account ID"
  value       = grafana_service_account.tf_scratch.id
}

output "service_account_key" {
  description = "Grafana service account API key (sensitive)"
  value       = grafana_service_account_token.tf_scratch.key
  sensitive   = true
}