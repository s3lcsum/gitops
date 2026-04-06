# Remote state from Authentik (OAuth app credentials). Only read when OAuth is enabled.
data "terraform_remote_state" "authentik" {
  count = var.enable_oauth ? 1 : 0

  backend = "gcs"

  config = {
    bucket = "dominiksiejak-gitops-tfstate"
    prefix = "gitops-authentik"
  }
}
