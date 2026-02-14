output "terraform_user_id" {
  description = "Terraform automation user ID."
  value       = proxmox_virtual_environment_user.terraform.user_id
}

output "terraform_token_id" {
  description = "Terraform API token ID."
  value       = "${proxmox_virtual_environment_user.terraform.user_id}!${proxmox_virtual_environment_user_token.terraform.token_name}"
}

output "authentik_groups" {
  description = "Authentik groups created in Proxmox."
  value       = { for k, v in proxmox_virtual_environment_group.authentik : k => v.group_id }
}

output "managed_roles" {
  description = "Custom roles managed by Terraform."
  value = {
    for key, role in proxmox_virtual_environment_role.managed : key => role.role_id
  }
}
