resource "random_password" "oauth2_client_secrets" {
  for_each = local.oauth2_applications

  length  = 40
  special = false
}

resource "authentik_property_mapping_provider_scope" "custom_claims" {
  for_each = {
    for k, v in local.oauth2_applications : k => v
    if lookup(v, "mapping", null) != null
  }

  name       = "${each.key}-custom-claims"
  scope_name = each.key
  expression = each.value.mapping
}

resource "authentik_provider_oauth2" "oauth2" {
  for_each = local.oauth2_applications

  name               = each.value.name
  client_id          = each.key
  client_secret      = random_password.oauth2_client_secrets[each.key].result
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  signing_key        = data.authentik_certificate_key_pair.generated.id

  property_mappings = lookup(each.value, "mapping", null) != null ? concat(
    data.authentik_property_mapping_provider_scope.oauth2_scopes.ids,
    [authentik_property_mapping_provider_scope.custom_claims[each.key].id]
  ) : data.authentik_property_mapping_provider_scope.oauth2_scopes.ids

  allowed_redirect_uris = [
    for uri in each.value.redirect_uris : {
      matching_mode = "strict"
      url           = uri
    }
  ]
}

resource "authentik_application" "oauth2" {
  for_each = local.oauth2_applications

  name              = each.value.name
  slug              = each.key
  protocol_provider = authentik_provider_oauth2.oauth2[each.key].id
  meta_icon         = each.value.icon_url
  meta_launch_url   = each.value.launch_url
}

resource "authentik_provider_proxy" "proxy" {
  for_each = local.proxy_applications

  name               = each.value.name
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  external_host      = each.value.external_host
  internal_host      = each.value.internal_host
  mode               = "forward_single"
  skip_path_regex    = each.value.skip_path_regex
}

resource "authentik_application" "proxy" {
  for_each = local.proxy_applications

  name              = each.value.name
  slug              = each.key
  protocol_provider = authentik_provider_proxy.proxy[each.key].id
  meta_icon         = each.value.icon_url
  meta_launch_url   = each.value.launch_url
}

resource "authentik_application" "dashboard" {
  for_each = local.dashboard_applications

  name            = each.value.name
  slug            = each.key
  meta_icon       = each.value.icon_url
  meta_launch_url = each.value.launch_url
}

locals {
  all_app_uuids = merge(
    { for k, _ in local.oauth2_applications : k => authentik_application.oauth2[k].uuid },
    { for k, _ in local.proxy_applications : k => authentik_application.proxy[k].uuid },
    { for k, _ in local.dashboard_applications : k => authentik_application.dashboard[k].uuid },
  )
}

resource "authentik_policy_binding" "admin_access" {
  for_each = local.all_app_uuids

  target = each.value
  group  = authentik_group.admins.id
  order  = 0
}

resource "authentik_policy_binding" "user_access" {
  for_each = {
    for app in local.user_accessible_apps : app => local.all_app_uuids[app]
    if contains(keys(local.all_app_uuids), app)
  }

  target = each.value
  group  = authentik_group.users.id
  order  = 1
}
