output "applications" {
  description = "OAuth2/OIDC configuration for all applications"
  value = {
    for slug, app in authentik_provider_oauth2.oauth2 : slug => {
      client_id     = app.client_id
      client_secret = app.client_secret
      issuer_uri    = "https://auth.${local.base_domain}/application/o/${slug}/"

      # Convenience: first redirect URI registered in Authentik for this app
      redirect_uri = local.oauth2_applications[slug].redirect_uris[0]
    }
  }
  sensitive = true
}
