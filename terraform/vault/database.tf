resource "vault_mount" "database" {
  path        = "database"
  type        = "database"
  description = "PostgreSQL credential management"
}

resource "vault_password_policy" "postgres_base64" {
  name = "postgres-base64"

  policy = <<-EOT
  length = 34

  rule "charset" {
    charset   = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    min-chars = 34
  }
  EOT
}

resource "vault_database_secret_backend_connection" "postgres" {
  backend       = vault_mount.database.path
  name          = "postgres"
  allowed_roles = [for _, db in local.databases : db.username]

  postgresql {
    connection_url = "postgresql://{{username}}:{{password}}@${var.postgres_host}:${var.postgres_port}/${var.postgres_admin_database}?sslmode=${var.postgres_sslmode}"
    username       = var.postgres_admin_user
  }
}

resource "vault_generic_endpoint" "postgres_password_policy" {
  path                 = "${vault_mount.database.path}/config/${vault_database_secret_backend_connection.postgres.name}"
  disable_read         = false
  disable_delete       = true
  ignore_absent_fields = true

  data_json = jsonencode({
    password_policy = vault_password_policy.postgres_base64.name
  })

  depends_on = [
    vault_database_secret_backend_connection.postgres,
    vault_password_policy.postgres_base64,
  ]
}

resource "vault_database_secret_backend_static_role" "databases" {
  for_each = local.databases

  backend = vault_mount.database.path
  name    = each.value.username
  db_name = vault_database_secret_backend_connection.postgres.name

  username        = each.value.username
  rotation_period = 31536000

  rotation_statements = [
    "ALTER USER \"{{name}}\" WITH PASSWORD '{{password}}'",
    "ALTER USER \"{{name}}\" WITH LOGIN PASSWORD '{{password}}'",
  ]
}
