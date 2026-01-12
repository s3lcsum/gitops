# =============================================================================
# Terraform Cloud outputs from other workspaces
# =============================================================================

# Pull Authentik OAuth2 credentials for Vault
data "tfe_outputs" "authentik" {
  organization = "dominiksiejak"
  workspace    = "gitops-authentik"
}

locals {
  # Authentik OIDC credentials for Vault
  authentik_vault_oidc = data.tfe_outputs.authentik.values.applications.vault

  # Authentik OIDC applications (sensitive values, non-sensitive keys)
  authentik_applications      = data.tfe_outputs.authentik.values.applications
  authentik_application_names = toset(nonsensitive(keys(local.authentik_applications)))
}