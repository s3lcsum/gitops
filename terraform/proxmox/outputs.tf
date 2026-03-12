output "terraform_user_id" {
  description = "Terraform automation user ID."
  value       = proxmox_virtual_environment_user.extra["terraform@pve"].user_id
}

output "metrics_api_token" {
  description = "API token for metrics@pve (VictoriaMetrics / pve-exporter)."
  value       = try(proxmox_virtual_environment_user_token.extra["metrics@pve"].value, null)
  sensitive   = true
}

output "authentik_groups" {
  description = "Authentik groups created in Proxmox."
  value       = { for k, v in proxmox_virtual_environment_group.authentik : k => v.group_id }
}

output "managed_roles" {
  description = "Custom roles managed by Terraform."
  value = {
    for key, role in proxmox_virtual_environment_role.authentik : key => role.role_id
  }
}

# Talos Kubernetes cluster outputs
output "kubeconfig" {
  description = "Kubernetes admin kubeconfig for the Talos cluster."
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "talos_nodes" {
  description = "Map of Talos node names to their IPs."
  value       = { for k, v in local.talos_nodes : k => v.ip }
}

output "talos_api_endpoint" {
  description = "Talos API endpoint for talosctl."
  value       = "https://${local.talos_first_cp_ip}:6443"
}

output "talos_client_config" {
  description = "Talos client configuration for talosctl."
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}
