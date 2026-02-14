resource "postgresql_role" "applications" {
  for_each = local.application_config

  name  = each.value.username
  login = true
  # password is managed by Vault
}

resource "postgresql_database" "applications" {
  for_each = local.application_config

  name  = each.value.database
  owner = postgresql_role.applications[each.key].name
}
