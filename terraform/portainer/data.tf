# Terraform Cloud outputs from Authentik workspace (OAuth app credentials). Only read when OAuth is enabled.
data "tfe_outputs" "authentik" {
  count = var.enable_oauth ? 1 : 0

  organization = "dominiksiejak"
  workspace    = "gitops-authentik"
}
