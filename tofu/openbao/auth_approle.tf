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
