# Enable OIDC auth method
resource "vault_jwt_auth_backend" "oidc" {
  path               = "oidc"
  type               = "oidc"
  description        = "Authentik"
  oidc_discovery_url = "https://auth.dominiksiejak.pl/application/o/vault/"
  oidc_client_id     = data.terraform_remote_state.authentik.outputs.applications.vault.client_id
  oidc_client_secret = data.terraform_remote_state.authentik.outputs.applications.vault.client_secret
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

  bound_audiences = [data.terraform_remote_state.authentik.outputs.applications.vault.client_id]
  allowed_redirect_uris = [
    "https://vault.dominiksiejak.pl/ui/vault/auth/oidc/oidc/callback",
    "https://vault.dominiksiejak.pl/oidc/callback",
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
    # Scoped admin for known mounts (no catch-all path "*")
    path "kv/*" {
      capabilities = ["create", "read", "update", "delete", "list", "patch"]
    }
    path "database/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "pki*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "auth/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "identity/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "cubbyhole/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "oidc/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "sys/mounts" {
      capabilities = ["read", "list"]
    }
    path "sys/mounts/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "sys/policy" {
      capabilities = ["read", "list"]
    }
    path "sys/policy/*" {
      capabilities = ["create", "read", "update", "delete"]
    }
    path "sys/policies/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "sys/auth" {
      capabilities = ["read", "list"]
    }
    path "sys/auth/*" {
      capabilities = ["create", "read", "update", "delete", "sudo"]
    }
    path "sys/health" {
      capabilities = ["read", "sudo"]
    }
    path "sys/capabilities-self" {
      capabilities = ["update"]
    }
    path "sys/capabilities" {
      capabilities = ["update"]
    }
    path "sys/internal/ui/mounts" {
      capabilities = ["read"]
    }
    path "sys/internal/ui/mounts/*" {
      capabilities = ["read"]
    }
    path "sys/internal/ui/resultant-acl" {
      capabilities = ["read"]
    }
    path "sys/audit" {
      capabilities = ["read", "list", "sudo"]
    }
    path "sys/audit/*" {
      capabilities = ["create", "read", "update", "delete", "sudo"]
    }
    path "sys/leases/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "sys/revoke" {
      capabilities = ["update", "sudo"]
    }
    path "sys/renew" {
      capabilities = ["update"]
    }
    path "sys/wrapping/*" {
      capabilities = ["create", "update"]
    }
    path "sys/tools/*" {
      capabilities = ["update"]
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
