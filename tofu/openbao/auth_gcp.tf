resource "vault_auth_backend" "gcp" {
  type = "gcp"
  path = "gcp"
}

resource "vault_gcp_auth_backend_role" "cicd_terraform" {
  backend                = vault_auth_backend.gcp.path
  role                   = local.cfg.cicd_openbao_gcp_role
  type                   = "iam"
  token_policies         = [vault_policy.terraform.name]
  token_ttl              = 3600
  token_max_ttl          = 14400
  bound_service_accounts = [local.cfg.cicd_gcp_service_account]
  # IAM JWT aud is vault/<role> (see cicd_openbao_gcp_audience in config.tf); not a TF attr.
}
