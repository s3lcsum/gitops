# Synology NAS Configuration Outputs

output "synology_host" {
  description = "Synology NAS hostname/IP"
  value       = var.synology_host
}

output "shared_folder_names" {
  description = "Names of configured shared folders"
  value       = keys(local.shared_folders)
}

output "shared_folder_paths" {
  description = "Paths of configured shared folders"
  value       = { for k, v in local.shared_folders : k => v.path }
}

output "user_names" {
  description = "Names of configured users"
  value       = keys(local.users)
}

output "group_names" {
  description = "Names of configured user groups"
  value       = keys(local.groups)
}

output "api_endpoints" {
  description = "Synology DSM API endpoints"
  value       = local.api_endpoints
}

# Configuration summary
output "configuration_summary" {
  description = "Summary of Synology NAS configuration"
  value = {
    host           = var.synology_host
    shared_folders = length(local.shared_folders)
    users          = length(local.users)
    groups         = length(local.groups)
  }
}
