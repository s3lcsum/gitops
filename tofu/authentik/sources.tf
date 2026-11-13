data "authentik_flow" "source_authentication" {
  slug = "default-source-authentication"
}

resource "authentik_source_oauth" "google" {
  name                = "Google"
  slug                = "google"
  provider_type       = "google"
  authentication_flow = data.authentik_flow.source_authentication.id
  user_matching_mode  = "email_link"
  enabled             = true

  consumer_key    = local.secret.google_client_id
  consumer_secret = local.secret.google_client_secret
}
