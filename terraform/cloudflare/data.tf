# Authentik OAuth2 credentials for the Cloudflare Zero Trust OIDC IdP.
data "terraform_remote_state" "authentik" {
  backend = "remote"
  config = {
    hostname     = "terrakube-api.dominiksiejak.pl"
    organization = "HomeLab"
    workspaces = {
      name = "authentik"
    }
  }
}
