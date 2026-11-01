resource "authentik_group" "admins" {
  name         = "admins"
  is_superuser = true
}

resource "authentik_group" "users" {
  name         = "users"
  is_superuser = false
}

# The old variables.tf object type supplied optional() defaults (is_admin=false,
# is_active=true, sshPublicKey=[]). local.cfg.users is a plain map, so the
# defaults are applied here with try().
resource "authentik_user" "users" {
  for_each = local.cfg.users

  username  = each.key
  name      = each.value.name
  email     = each.value.email
  is_active = try(each.value.is_active, true)
  groups = try(each.value.is_admin, false) ? [
    authentik_group.admins.id,
    authentik_group.users.id
  ] : [authentik_group.users.id]
  attributes = jsonencode({
    sshPublicKey = try(each.value.sshPublicKey, [])
  })
}

resource "authentik_user" "service_accounts" {
  for_each = local.cfg.service_accounts

  username = each.key
  name     = each.value.name
  type     = "service_account"
  path     = "service-accounts"
  groups   = try(each.value.is_admin, false) ? [authentik_group.admins.id] : []
}
