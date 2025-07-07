resource "authentik_provider_oauth2" "apps" {
  for_each = local.authentik_oauth2_apps

  name      = title(each.key)
  client_id = each.key

  allowed_redirect_uris = [
    for url in each.value.urls :
    {
      matching_mode = "strict",
      url           = url
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

resource "authentik_application" "apps" {
  for_each = local.authentik_oauth2_apps

  name               = each.key
  slug               = each.key
  meta_icon          = "application-icons/${each.key}.png"
  policy_engine_mode = "all"
  protocol_provider  = authentik_provider_oauth2.apps[each.key].id

  lifecycle {
    ignore_changes = [
      # For some reasons the providers always adds /media/public to the path, and always triggers the change
      meta_icon,
    ]
  }
}

output "apps_oauth2_settings" {
  sensitive = true
  value = [for k, v in local.authentik_oauth2_apps : {
    issuer        = "${var.authentik_url}/application/o/"
    client_id     = authentik_provider_oauth2.apps[k].client_id
    client_secret = authentik_provider_oauth2.apps[k].client_secret
    redirect_uri  = authentik_provider_oauth2.apps[k].allowed_redirect_uris[0].url
    auth_url      = "${var.authentik_url}/application/o/authorize/"
    token_url     = "${var.authentik_url}/application/o/token/"
    userinfo_url  = "${var.authentik_url}/application/o/userinfo/"
  }]
}
