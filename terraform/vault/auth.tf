# Enable OIDC auth method
resource "vault_jwt_auth_backend" "oidc" {
  path               = "oidc"
  type               = "oidc"
  description        = "" # Leave empty for security reasons
  oidc_discovery_url = local.authentik_vault_oidc.issuer_url
  oidc_client_id     = local.authentik_vault_oidc.client_id
  oidc_client_secret = local.authentik_vault_oidc.client_secret
  default_role       = "admin"

  tune {
    default_lease_ttl = "1h"
    max_lease_ttl     = "24h"
    token_type        = "default-service"
  }
}

resource "vault_jwt_auth_backend_role" "admin" {
  backend   = vault_jwt_auth_backend.oidc.path
  role_name = "admin"
  role_type = "oidc"

  user_claim   = "preferred_username"
  groups_claim = "groups"

  # Only allow users in the admins group
  bound_claims = {
    groups = "admins"
  }

  bound_audiences = [local.authentik_vault_oidc.client_id]
  allowed_redirect_uris = [
    "https://vault.lake.dominiksiejak.pl/ui/vault/auth/oidc/oidc/callback",
    "https://vault.lake.dominiksiejak.pl/oidc/callback",
    "http://localhost:8250/oidc/callback"
  ]

  oidc_scopes    = ["openid", "profile", "email", "preferred_username", "groups"]
  token_policies = [vault_policy.admin.name]

  token_ttl     = 3600
  token_max_ttl = 86400
}

resource "vault_policy" "admin" {
  name = "admin"

  policy = <<-EOT
    # Full access to all paths
    path "*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
  EOT
}

resource "vault_identity_group" "admins" {
  name     = "authentik-admins"
  type     = "external"
  policies = [vault_policy.admin.name]
}

resource "vault_identity_group_alias" "admins" {
  name           = "admins"
  mount_accessor = vault_jwt_auth_backend.oidc.accessor
  canonical_id   = vault_identity_group.admins.id
}

