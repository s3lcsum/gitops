resource "authentik_group" "admins" {
  name         = "admins"
  is_superuser = true
}

resource "authentik_group" "users" {
  name         = "users"
  is_superuser = false
}

# Jellyfin RBAC groups (aussierk/jellyfin-plugin-oidc).
#
# The plugin's Role Mappings tab matches its Role Name against whatever the
# Role Claim Path resolves to. With Role Claim Path `groups` and authentik's
# default `profile` scope, that is the raw authentik group name — hence the
# `jellyfin-` prefix, so a Jellyfin role can never be granted by an unrelated
# group (or by `admins`, which would silently make every authentik admin a
# Jellyfin admin).
#
# A user in no jellyfin-* group matches no role mapping and, because the plugin
# is fail-closed by default, cannot sign in. That is intended: membership here
# is the admission gate.
resource "authentik_group" "jellyfin" {
  for_each = local.jellyfin_groups

  name         = each.key
  is_superuser = false
}

# The old variables.tf object type supplied optional() defaults (is_admin=false,
# is_active=true, sshPublicKey=[]). local.cfg.users is a plain map, so the
# defaults are applied here with try().

moved {
  from = authentik_user.users["wiktoriakrzywonos6"]
  to   = authentik_user.users["wkrzywonos"]
}

resource "authentik_user" "users" {
  for_each = local.cfg.users

  username  = each.key
  name      = each.value.name
  email     = each.value.email
  is_active = try(each.value.is_active, true)
  groups = concat(
    try(each.value.is_admin, false) ? [
      authentik_group.admins.id,
      authentik_group.users.id
    ] : [authentik_group.users.id],
    # jellyfin_role = "admins" | "users" | "kids"; null/absent = no Jellyfin access.
    [for role in [try(each.value.jellyfin_role, null)] :
      authentik_group.jellyfin["jellyfin-${role}"].id
    if role != null]
  )
  attributes = jsonencode(merge(
    { sshPublicKey = try(each.value.sshPublicKey, []) },
    try(each.value.welcome_email, true) ? {} : { welcome_email = false },
  ))
}

resource "authentik_user" "service_accounts" {
  for_each = local.cfg.service_accounts

  username = each.key
  name     = each.value.name
  type     = "service_account"
  path     = "service-accounts"
  groups   = try(each.value.is_admin, false) ? [authentik_group.admins.id] : []
}
