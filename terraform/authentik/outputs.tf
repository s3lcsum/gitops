output "applications" {
  description = "OAuth2/OIDC configuration for all applications"
  value = {
    for slug, app in authentik_provider_oauth2.oauth2 : slug => {
      client_id     = app.client_id
      client_secret = app.client_secret
      issuer_uri    = "https://auth.${local.base_domain}/application/o/${slug}/"

      # Convenience: first redirect URI registered in Authentik for this app
      redirect_uri = local.oauth2_applications[slug].redirect_uris[0]

      # Standard Authentik OAuth2 endpoints (used by Portainer and other RPs).
      # resource_uri is the userinfo endpoint, not the issuer — Portainer's
      # "Resource URL" fetches claims after the callback; pointing it at the
      # issuer (which 302s to discovery) breaks login.
      authorization_uri = "https://auth.${local.base_domain}/application/o/authorize/"
      access_token_uri  = "https://auth.${local.base_domain}/application/o/token/"
      logout_uri        = "https://auth.${local.base_domain}/application/o/${slug}/end-session/"
      resource_uri      = "https://auth.${local.base_domain}/application/o/userinfo/"
    }
  }
  sensitive = true
}

output "webhook_secret" {
  description = "Shared secret for Authentik → n8n firewall webhook"
  value       = random_password.webhook_secret.result
  sensitive   = true
}
