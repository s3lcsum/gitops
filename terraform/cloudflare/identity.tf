# Authentik as a Cloudflare Zero Trust Access identity provider (generic OIDC).
# Apply terraform/authentik first so remote-state applications.cloudflare exists.
#
# API token needs: Access: Organizations, Identity Providers, and Groups Write
resource "cloudflare_zero_trust_access_identity_provider" "authentik" {
  account_id = var.cloudflare_account_id
  name       = "Authentik"
  type       = "oidc"

  config = {
    client_id        = data.terraform_remote_state.authentik.outputs.applications.cloudflare.client_id
    client_secret    = data.terraform_remote_state.authentik.outputs.applications.cloudflare.client_secret
    auth_url         = data.terraform_remote_state.authentik.outputs.applications.cloudflare.authorization_uri
    token_url        = data.terraform_remote_state.authentik.outputs.applications.cloudflare.access_token_uri
    certs_url        = data.terraform_remote_state.authentik.outputs.applications.cloudflare.jwks_uri
    scopes           = ["openid", "email", "profile"]
    email_claim_name = "email"
    pkce_enabled     = true
  }
}
