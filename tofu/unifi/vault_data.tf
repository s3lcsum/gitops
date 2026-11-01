# Residual secrets for regular resource attrs (no write-only on target provider).
# Provider creds still come from ephemeral local.secret (vault_env.tf).
data "vault_kv_secret_v2" "module_env" {
  mount = "secret"
  name  = "unifi"
}

locals {
  vault = {
    for k, v in data.vault_kv_secret_v2.module_env.data : k => try(jsondecode(v), v)
    if !startswith(k, "__")
  }
}
