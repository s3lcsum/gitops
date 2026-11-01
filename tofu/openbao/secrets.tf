resource "vault_mount" "secret" {
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "KV v2 application secrets (paths secret/<app>/...)"
}
