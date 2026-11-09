# OpenBao 2.7.2's catalog has no gcp auth plugin (enable returns
# "plugin not found"). GitHub Actions and any cloud env that can mint a
# Google ID token for github-actions-tofu log in through the jwt method.
# Audience must match cicd_openbao_gcp_audience. Include the email claim.

removed {
  from = vault_auth_backend.gcp

  lifecycle {
    destroy = false
  }
}

removed {
  from = vault_gcp_auth_backend_role.cicd_terraform

  lifecycle {
    destroy = false
  }
}

import {
  to = vault_jwt_auth_backend.gcp_sa
  id = "jwt"
}

import {
  to = vault_jwt_auth_backend_role.cicd_terraform
  id = "auth/jwt/role/cicd-terraform"
}

resource "vault_jwt_auth_backend" "gcp_sa" {
  path               = "jwt"
  oidc_discovery_url = "https://accounts.google.com"
  bound_issuer       = "https://accounts.google.com"
  description        = "Google ID tokens for the OpenTofu CI service account"
}

resource "vault_jwt_auth_backend_role" "cicd_terraform" {
  backend         = vault_jwt_auth_backend.gcp_sa.path
  role_name       = local.cfg.cicd_openbao_gcp_role
  role_type       = "jwt"
  user_claim      = "email"
  bound_audiences = [local.cfg.cicd_openbao_gcp_audience]
  bound_claims = {
    email = local.cfg.cicd_gcp_service_account
  }
  token_policies = [vault_policy.terraform.name]
  token_ttl      = 3600
  token_max_ttl  = 14400
}
