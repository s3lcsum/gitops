# OAuth client_secret is owned by tofu/authentik (random_password in state).
data "terraform_remote_state" "authentik" {
  backend = "gcs"
  config = {
    bucket = "dominiksiejak-gitops-tfstate"
    prefix = "gitops-authentik"
  }
}
