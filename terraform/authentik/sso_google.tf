# Enabling Google SSO in Authentiko
#
# WARN: As default this integration does not recogize the username, only emails.
#
# For more info you can visit this page:
# @ref: https://docs.goauthentik.io/docs/users-sources/sources/social-logins/google/cloud/
resource "authentik_source_oauth" "google" {
  name = "google"
  slug = "google"

  provider_type      = "google"
  consumer_key       = var.authentik_sso_google_client_id
  consumer_secret    = var.authentik_sso_google_client_secret
  user_matching_mode = "email_link" # default was "indentifier" which I've already explained are not working by default

  authentication_flow = data.authentik_flow.default_source_authentication.id
  enrollment_flow     = data.authentik_flow.default_source_enrollment.id

  lifecycle {
    ignore_changes = [
      access_token_url,
      authorization_url,
      oidc_jwks_url,
      profile_url
    ]
  }
}
