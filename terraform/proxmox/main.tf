# -----------------------------------------------------------------------------
# OIDC (Authentik) realm
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_realm_openid" "authentik" {
  count = local.enable_oidc && var.oidc_client_secret != "" ? 1 : 0

  realm      = local.oidc_realm
  issuer_url = var.oidc_issuer_url
  client_id  = var.oidc_client_id
  client_key = var.oidc_client_secret

  autocreate     = local.oidc_autocreate
  username_claim = local.oidc_username_claim
  scopes         = "openid email profile"
  query_userinfo = true
  comment        = "Authentik OIDC managed by OpenTofu"
}

# -----------------------------------------------------------------------------
# Extra users (terraform + metrics)
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_user" "extra" {
  for_each = local.extra_users

  user_id = each.key
  comment = each.value.comment
  enabled = each.value.enabled

  lifecycle {
    ignore_changes = [acl]
  }
}

resource "proxmox_virtual_environment_user_token" "extra" {
  for_each = {
    for k, v in local.extra_user_tokens : k => v
    if contains(keys(local.extra_users), k)
  }

  user_id               = proxmox_virtual_environment_user.extra[each.key].user_id
  token_name            = each.value.token_name
  comment               = lookup(each.value, "comment", "Managed by OpenTofu")
  privileges_separation = false # Required for Terraform to manage Proxmox resources
}

# Metrics read-only role and ACL
resource "proxmox_virtual_environment_role" "metrics_readonly" {
  role_id    = "metrics-readonly"
  privileges = local.metrics_role_privileges
}

resource "proxmox_virtual_environment_acl" "metrics" {
  path    = "/"
  role_id = proxmox_virtual_environment_role.metrics_readonly.role_id
  user_id = proxmox_virtual_environment_user.extra["metrics@pve"].user_id
}

# -----------------------------------------------------------------------------
# Authentik groups and roles (OIDC mapping)
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_group" "authentik" {
  for_each = toset(local.authentik_groups)

  group_id = each.key
  comment  = "Managed by OpenTofu"

  lifecycle {
    ignore_changes = [acl]
  }
}

resource "proxmox_virtual_environment_role" "authentik" {
  for_each = local.authentik_roles

  role_id    = each.value.role_id
  privileges = each.value.privileges
}
