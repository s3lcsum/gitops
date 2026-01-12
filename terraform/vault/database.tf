resource "vault_mount" "database" {
  path        = "database"
  type        = "database"
  description = "PostgreSQL credential management"
}

resource "vault_database_secret_backend_connection" "postgres" {
  backend = vault_mount.database.path
  name    = "postgres"

  postgresql {
    connection_url = "postgresql://{{username}}:{{password}}@postgres:5432/postgres?sslmode=disable"
    username       = var.postgres_admin_user
    password       = var.postgres_admin_password
  }
}

resource "vault_database_secret_backend_role" "databases" {
  for_each = local.databases

  backend = vault_mount.database.path
  name    = each.key
  db_name = vault_database_secret_backend_connection.postgres.name

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT ALL PRIVILEGES ON DATABASE ${each.value.database} TO \"{{name}}\";",
    "GRANT ALL PRIVILEGES ON SCHEMA public TO \"{{name}}\";",
    "GRANT ALL ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
    "GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";",
    "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO \"{{name}}\";",
    "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO \"{{name}}\";"
  ]

  revocation_statements = [
    "REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM \"{{name}}\";",
    "REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM \"{{name}}\";",
    "REVOKE ALL PRIVILEGES ON SCHEMA public FROM \"{{name}}\";",
    "REVOKE ALL PRIVILEGES ON DATABASE ${each.value.database} FROM \"{{name}}\";",
    "DROP ROLE IF EXISTS \"{{name}}\";"
  ]

  default_ttl = 3600  # 1 hour
  max_ttl     = 86400 # 24 hours
}
