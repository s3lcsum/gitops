resource "proxmox_virtual_environment_user" "terraform" {
  user_id = "terraform"
  comment = "Managed by OpenTofu"
  enabled = true
}

resource "proxmox_virtual_environment_user_token" "terraform" {
  user_id    = proxmox_virtual_environment_user.terraform.user_id
  token_name = "provider"
  comment    = "Managed by OpenTofu"
}

resource "proxmox_virtual_environment_group" "authentik" {
  for_each = toset(local.groups)

  group_id = each.key
  comment  = "Managed by OpenTofu"
}

resource "proxmox_virtual_environment_role" "managed" {
  for_each = local.roles

  role_id    = each.value.role_id
  privileges = each.value.privileges
}
