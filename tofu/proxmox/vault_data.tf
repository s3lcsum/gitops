# Residual secrets for regular resource attrs (no write-only on target provider).
# Provider creds stay in local.secret (ephemeral, vault_env.tf).
data "vault_kv_secret_v2" "module_env" {
  mount = "secret"
  name  = "proxmox"
}

locals {
  vault = {
    for k, v in data.vault_kv_secret_v2.module_env.data : k => try(jsondecode(v), v)
    if !startswith(k, "__")
  }
}
