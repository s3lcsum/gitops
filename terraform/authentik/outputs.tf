output "applications" {
  description = "OAuth2/OIDC configuration for all applications"
  value = {
    for key, app in local.oauth2_applications : key => {
      client_id   = authentik_provider_oauth2.oauth2[key].client_id
      client_secret = authentik_provider_oauth2.oauth2[key].client_secret
      issuer_url  = "https://auth.${local.base_domain}/application/o/${app.slug}/"
      base_url    = app.base_url
    }
  }
  sensitive = true
}

output "ldap_service_accounts" {
  description = "LDAP service account credentials"
  value = {
    for key, sa in authentik_user.service_accounts : key => {
      bind_dn  = "cn=${sa.username},ou=users,${local.ldap.base_dn}"
      password = var.service_accounts[key].password
    }
  }
  sensitive = true
}
