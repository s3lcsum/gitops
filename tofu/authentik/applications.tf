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

# Provides the `groups` claim to CWA (calibre-web-automated) so it can auto-assign
# the admin role based on Authentik group membership (admin group = "admins").
resource "authentik_property_mapping_provider_scope" "calibre_web_groups" {
  name       = "calibre-web-automated-groups"
  scope_name = "groups"
  expression = "return [g.name for g in request.user.ak_groups.all()]"
}

resource "authentik_property_mapping_provider_scope" "argocd_groups" {
  name       = "argocd-groups"
  scope_name = "groups"
  expression = "return [g.name for g in request.user.ak_groups.all()]"
}

resource "authentik_property_mapping_provider_scope" "openbao_groups" {
  name       = "openbao-groups"
  scope_name = "groups"
  expression = "return [g.name for g in request.user.ak_groups.all()]"
}

# Extra `groups` scope for legacy SSO-Auth.xml (still mounted on Jellyfin). The aussierk
# plugin uses `openid profile email` only. Drop this mapping when SSO-Auth.xml is removed.
resource "authentik_property_mapping_provider_scope" "jellyfin_groups" {
  name       = "jellyfin-groups"
  scope_name = "groups"
  expression = "return [g.name for g in request.user.ak_groups.all()]"
}

resource "authentik_provider_oauth2" "oauth2" {
  for_each = local.oauth2_applications

  name               = each.value.name
  client_id          = each.key
  client_type        = lookup(each.value, "client_type", "confidential")
  client_secret      = random_password.oauth2_client_secrets[each.key].result
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  signing_key        = data.authentik_certificate_key_pair.generated.id

  # Grant types the provider is allowed to use. Without "authorization_code"
  # Authentik rejects the authorization request ("The request is otherwise
  # malformed"), so an explicit list is required rather than relying on a
  # possibly-empty default.
  grant_types = [
    "authorization_code",
    "refresh_token",
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.oauth2_scopes.ids,
    lookup(each.value, "mapping", null) != null ? [authentik_property_mapping_provider_scope.custom_claims[each.key].id] : [],
    each.key == "calibre-web-automated" ? [authentik_property_mapping_provider_scope.calibre_web_groups.id] : [],
    each.key == "argocd" ? [authentik_property_mapping_provider_scope.argocd_groups.id] : [],
    each.key == "openbao" ? [authentik_property_mapping_provider_scope.openbao_groups.id] : [],
    each.key == "jellyfin" ? [authentik_property_mapping_provider_scope.jellyfin_groups.id] : [],
  )

  # aussierk/jellyfin-plugin-oidc reads the role claim from the ID token first,
  # then the access token, then userinfo. Default is already true; pinned
  # explicitly so a provider-level change can't silently break the RBAC claim.
  include_claims_in_id_token = true

  # Account identity in the plugin is keyed on `sub`. Per-provider issuer is
  # what the plugin's discovery pinning expects (iss = .../application/o/<slug>/).
  issuer_mode = "per_provider"
  sub_mode    = lookup(each.value, "sub_mode", "hashed_user_id")

  # Back-channel logout: authentik POSTs a signed logout_token on session end.
  # logout_uri is only set for apps that expose the OIDC back-channel endpoint;
  # null elsewhere. logout_method defaults to `backchannel`.
  logout_uri = lookup(each.value, "logout_uri", null)

  allowed_redirect_uris = [
    for uri in each.value.redirect_uris : {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = uri
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
  # Intersect config keys with resources in state so evaluation succeeds when config and state drift
  # (e.g. dashboard apps renamed or not yet applied).
  all_app_uuids = merge(
    { for k in setintersection(keys(local.oauth2_applications), keys(authentik_application.oauth2)) : k => authentik_application.oauth2[k].uuid },
    { for k in setintersection(keys(local.proxy_applications), keys(authentik_application.proxy)) : k => authentik_application.proxy[k].uuid },
    { for k in setintersection(keys(local.dashboard_applications), keys(authentik_application.dashboard)) : k => authentik_application.dashboard[k].uuid },
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

# Jellyfin app access for the RBAC groups. Authentik authorizes the app before
# the plugin ever sees a token, so a user in `jellyfin-users` but not in `users`
# would be denied at the Authentik consent step. Bind each jellyfin-* group to
# the Jellyfin application only.
resource "authentik_policy_binding" "jellyfin_rbac_access" {
  for_each = {
    for name, group in authentik_group.jellyfin : name => group.id
    if contains(keys(local.all_app_uuids), "jellyfin")
  }

  target = local.all_app_uuids["jellyfin"]
  group  = each.value
  order  = 2
}
