resource "authentik_group" "admins" {
  name         = "admins"
  is_superuser = true
}

resource "authentik_group" "users" {
  name         = "users"
  is_superuser = false
}

resource "authentik_user" "users" {
  for_each = var.users

  username  = each.key
  name      = each.value.name
  email     = each.value.email
  is_active = each.value.is_active
  groups = each.value.is_admin ? [
    authentik_group.admins.id,
    authentik_group.users.id
  ] : [authentik_group.users.id]
  attributes = jsonencode({
    sshPublicKey = each.value.sshPublicKey
  })
}

resource "authentik_user" "service_accounts" {
  for_each = var.service_accounts

  username = each.key
  name     = each.value.name
  type     = "service_account"
  path     = "service-accounts"
  groups   = each.value.is_admin ? [authentik_group.admins.id] : []
}

resource "authentik_token" "service_account_tokens" {
  for_each = var.service_accounts

  user        = authentik_user.service_accounts[each.key].id
  identifier  = "${each.key}-ldap-token"
  intent      = "app_password"
  description = "LDAP bind password for ${each.value.name}"
}
