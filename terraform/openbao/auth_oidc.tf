resource "vault_jwt_auth_backend" "oidc" {
  path               = "oidc"
  type               = "oidc"
  oidc_discovery_url = "https://auth.dominiksiejak.pl/application/o/openbao/"
  oidc_client_id     = var.oidc_client_id
  oidc_client_secret = var.oidc_client_secret
  default_role       = "admin"
  tune {
    listing_visibility = "unauth"
  }
}

resource "vault_jwt_auth_backend_role" "admin" {
  backend        = vault_jwt_auth_backend.oidc.path
  role_name      = "admin"
  role_type      = "oidc"
  token_policies = [vault_policy.admin.name]

  user_claim   = "sub"
  groups_claim = "groups"
  oidc_scopes  = ["openid", "profile", "email", "groups"]
  allowed_redirect_uris = [
    "https://openbao.dominiksiejak.pl/ui/vault/auth/oidc/oidc/callback",
  ]
  bound_audiences = [var.oidc_client_id]
}
