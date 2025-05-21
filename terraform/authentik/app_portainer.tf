resource "authentik_provider_oauth2" "portainer" {
  name      = "portainer"
  client_id = "portainer"

  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "https://portainer.wally.dominiksiejak.pl/",
    }
  ]

  authorization_flow  = data.authentik_flow.default_authorization_flow.id
  authentication_flow = data.authentik_flow.default_authentication_flow.id
  invalidation_flow   = data.authentik_flow.default_invalidation_flow.id

  signing_key = data.authentik_certificate_key_pair.default.id

  property_mappings = [
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    data.authentik_property_mapping_provider_scope.openid.id,
  ]
}

resource "authentik_application" "portainer" {
  name               = "Portainer"
  slug               = "portainer"
  meta_icon          = "/media/public/application-icons/portainer.png"
  policy_engine_mode = "all"
  protocol_provider  = authentik_provider_oauth2.portainer.id
}

output "portainer_oauth2_settings" {
  sensitive = true
  value = {
    issuer        = "${var.authentik_url}/application/o/"
    client_id     = authentik_provider_oauth2.portainer.client_id
    client_secret = authentik_provider_oauth2.portainer.client_secret
    redirect_uri  = authentik_provider_oauth2.portainer.allowed_redirect_uris[0].url
    auth_url      = "${var.authentik_url}/application/o/authorize/"
    token_url     = "${var.authentik_url}/application/o/token/"
    userinfo_url  = "${var.authentik_url}/application/o/userinfo/"
  }
}
