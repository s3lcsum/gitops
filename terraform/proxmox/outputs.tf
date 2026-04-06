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

output "talos_cluster_endpoint" {
  description = "Kubernetes API URL (first control-plane node; from bbtechsys/talos/proxmox after apply)."
  value       = "https://${module.talos_lake.control_plane_ips[0]}:6443"
}

output "talos_control_plane_fqdns" {
  description = "Control-plane FQDNs when talos_node_domain is set (create A/AAAA records to talos_nodes IPv4s)."
  value       = local.talos_cp_fqdns
}

output "talos_control_plane_ips" {
  description = "Control-plane IPv4s (from Proxmox guest agent via bbtechsys module). Compare to locals.talos_nodes for RouterOS DHCP lease verification."
  value       = module.talos_lake.control_plane_ips
}

output "talos_vm_macs" {
  description = "Talos VM NIC MAC addresses (names match Proxmox / module: talos-cp-1, …)."
  value       = { for k, v in local.talos_nodes : "talos-${k}" => v.mac }
}

output "talos_routeros_dhcp_leases" {
  description = "RouterOS DHCP static lease targets (IP → MAC). Pool 192.168.89.100–199 is dynamic; use 200–239 for Talos. DNAT 80/443 → MetalLB pool 192.168.89.240–249."
  value = {
    for k, v in local.talos_nodes : k => {
      address = v.ipv4
      mac     = v.mac
    }
  }
}

output "talosconfig" {
  description = "Talos client configuration (talosctl). Regenerate via: terraform output -raw talosconfig > generated/talosconfig.yaml"
  value       = module.talos_lake.talos_config
  sensitive   = true
}

output "kubeconfig" {
  description = "Cluster kubeconfig. Regenerate via: terraform output -raw kubeconfig > generated/kubeconfig"
  value       = module.talos_lake.kubeconfig
  sensitive   = true
}
