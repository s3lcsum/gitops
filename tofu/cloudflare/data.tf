# Authentik OAuth2 credentials for the Cloudflare Zero Trust OIDC IdP.
data "terraform_remote_state" "authentik" {
  backend = "gcs"
  config = {
    bucket = "dominiksiejak-gitops-tfstate"
    prefix = "gitops-authentik"
  }
}
