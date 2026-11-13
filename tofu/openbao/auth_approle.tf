resource "vault_auth_backend" "approle" {
  type = "approle"
  path = "approle"
}

resource "vault_approle_auth_backend_role" "terraform" {
  backend        = vault_auth_backend.approle.path
  role_name      = "terraform"
  token_policies = [vault_policy.terraform.name]
  token_ttl      = 3600
  token_max_ttl  = 14400
  secret_id_ttl  = 0
}

locals {
  # vibe-vm runs OpenTofu: the provider mints a limited child token, which
  # client-read cannot do (403 auth/token/create). CI uses the same policy.
  client_approles = {
    cursor    = [vault_policy.client_read.name]
    github    = [vault_policy.client_read.name]
    "vibe-vm" = [vault_policy.terraform.name]
  }
}

resource "vault_approle_auth_backend_role" "clients" {
  for_each       = local.client_approles
  backend        = vault_auth_backend.approle.path
  role_name      = each.key
  token_policies = each.value
  token_ttl      = 3600
  token_max_ttl  = 14400
  secret_id_ttl  = 0
}

resource "vault_approle_auth_backend_role_secret_id" "clients" {
  for_each  = local.client_approles
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.clients[each.key].role_name
}

output "client_approle_credentials" {
  sensitive = true
  value = {
    for name, role in vault_approle_auth_backend_role.clients : name => {
      role_id   = role.role_id
      secret_id = vault_approle_auth_backend_role_secret_id.clients[name].secret_id
    }
  }
}
