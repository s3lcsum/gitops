# Terraform Cloud outputs from Authentik workspace
# Only read when OAuth is enabled (workspace must exist)
data "tfe_outputs" "authentik" {
  count        = var.enable_oauth ? 1 : 0
  organization = "s3lcsum"
  workspace    = "gitops-authentik"
}
