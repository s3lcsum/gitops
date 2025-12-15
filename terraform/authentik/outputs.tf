output "applications" {
  description = "OAuth configuration for all applications"
  value = {
    portainer = {
      client_id         = authentik_provider_oauth2.oauth2["portainer"].client_id
      client_secret     = authentik_provider_oauth2.oauth2["portainer"].client_secret
      access_token_uri  = "https://auth.${local.base_domain}/application/o/token/"
      authorization_uri = "https://auth.${local.base_domain}/application/o/authorize/"
      logout_uri        = "https://auth.${local.base_domain}/application/o/portainer/end-session/"
      redirect_uri      = "https://portainer.${local.base_domain}"
      resource_uri      = "https://auth.${local.base_domain}/application/o/userinfo/"
    }
    proxmox = {
      client_id     = authentik_provider_oauth2.oauth2["proxmox"].client_id
      client_secret = authentik_provider_oauth2.oauth2["proxmox"].client_secret
      issuer_url    = "https://auth.${local.base_domain}/application/o/proxmox/"
    }
    netbox = {
      client_id     = authentik_provider_oauth2.oauth2["netbox"].client_id
      client_secret = authentik_provider_oauth2.oauth2["netbox"].client_secret
      oidc_endpoint = "https://auth.${local.base_domain}/application/o/netbox/"
      logout_url    = "https://auth.${local.base_domain}/application/o/netbox/end-session/"
    }
    vaultwarden = {
      client_id     = authentik_provider_oauth2.oauth2["vaultwarden"].client_id
      client_secret = authentik_provider_oauth2.oauth2["vaultwarden"].client_secret
      authority     = "https://auth.${local.base_domain}/application/o/vaultwarden/"
    }
    synology = {
      client_id      = authentik_provider_oauth2.oauth2["synology"].client_id
      client_secret  = authentik_provider_oauth2.oauth2["synology"].client_secret
      well_known_url = "https://auth.${local.base_domain}/application/o/synology/.well-known/openid-configuration"
    }
    n8n = {
      client_id     = authentik_provider_oauth2.oauth2["n8n"].client_id
      client_secret = authentik_provider_oauth2.oauth2["n8n"].client_secret
      issuer_url    = "https://auth.${local.base_domain}/application/o/n8n/"
    }
    warrtracker = {
      client_id     = authentik_provider_oauth2.oauth2["warrtracker"].client_id
      client_secret = authentik_provider_oauth2.oauth2["warrtracker"].client_secret
      issuer_url    = "https://auth.${local.base_domain}/application/o/warrtracker/"
    }
  }
  sensitive = true
}

output "ldap_service_accounts" {
  description = "LDAP service account credentials"
  value = {
    for key, sa in authentik_user.service_accounts : key => {
      bind_dn  = "cn=${sa.username},ou=users,${local.ldap.base_dn}"
      password = authentik_token.service_account_tokens[key].key
    }
  }
  sensitive = true
}
