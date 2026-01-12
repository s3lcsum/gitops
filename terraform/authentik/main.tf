########################################################
# GROUPS
########################################################
resource "authentik_group" "groups" {
  for_each = local.groups

  name         = each.value.name
  is_superuser = each.value.is_superuser
}

########################################################
# USERS
########################################################
resource "authentik_user" "users" {
  for_each = var.users

  username  = each.key
  name      = each.value.name
  email     = each.value.email
  is_active = each.value.is_active
  groups    = [for g in each.value.groups : authentik_group.groups[g].id]
  attributes = jsonencode({
    sshPublicKey = each.value.sshPublicKey
  })
}

########################################################
# SERVICE ACCOUNTS (for LDAP binds)
########################################################
resource "authentik_user" "service_accounts" {
  for_each = var.service_accounts

  username = each.key
  name     = each.value.name
  type     = "service_account"
  path     = "service-accounts"
  groups = concat(
    [authentik_group.groups["ldap_search"].id],
    each.value.is_admin ? [authentik_group.groups["admins"].id] : []
  )
}

resource "authentik_token" "service_account_tokens" {
  for_each = var.service_accounts

  user        = authentik_user.service_accounts[each.key].id
  identifier  = "${each.key}-ldap-token"
  intent      = "app_password"
  description = "LDAP bind password for ${each.value.name}"
}

########################################################
# GOOGLE SSO SOURCE
########################################################
# resource "authentik_source_oauth" "google" {
#   name                = "Google"
#   slug                = "google"
#   authentication_flow = data.authentik_flow.default-source-authentication.id
#   enrollment_flow     = data.authentik_flow.default-source-enrollment.id
#   provider_type       = "google"
#   consumer_key        = local.google_oauth.client_id
#   consumer_secret     = local.google_oauth.client_secret
# }

########################################################
# DOCKER SERVICE CONNECTION
########################################################
resource "authentik_service_connection_docker" "local" {
  name  = "docker-local"
  local = true
}

########################################################
# LDAP AUTHENTICATION FLOW (No MFA)
########################################################
resource "authentik_flow" "ldap_authentication" {
  name               = "ldap-authentication-flow"
  title              = "LDAP Authentication"
  slug               = "ldap-authentication-flow"
  designation        = "authentication"
  policy_engine_mode = "any"
}

resource "authentik_stage_identification" "ldap_identification" {
  name               = "ldap-identification"
  user_fields        = ["username", "email"]
  show_source_labels = false
}

resource "authentik_stage_password" "ldap_password" {
  name     = "ldap-password"
  backends = ["authentik.core.auth.InbuiltBackend"]
}

resource "authentik_stage_user_login" "ldap_login" {
  name                     = "ldap-login"
  session_duration         = "seconds=0"
  terminate_other_sessions = false
}

resource "authentik_flow_stage_binding" "ldap_identification" {
  target = authentik_flow.ldap_authentication.uuid
  stage  = authentik_stage_identification.ldap_identification.id
  order  = 10
}

resource "authentik_flow_stage_binding" "ldap_password" {
  target = authentik_flow.ldap_authentication.uuid
  stage  = authentik_stage_password.ldap_password.id
  order  = 20
}

resource "authentik_flow_stage_binding" "ldap_login" {
  target = authentik_flow.ldap_authentication.uuid
  stage  = authentik_stage_user_login.ldap_login.id
  order  = 30
}

########################################################
# LDAP PROVIDER & OUTPOST
########################################################
resource "authentik_provider_ldap" "ldap" {
  name        = "ldap-provider"
  base_dn     = local.ldap.base_dn
  bind_flow   = authentik_flow.ldap_authentication.uuid
  unbind_flow = data.authentik_flow.default-invalidation-flow.id
}

resource "authentik_application" "ldap" {
  name              = "LDAP"
  slug              = "ldap"
  protocol_provider = authentik_provider_ldap.ldap.id
  meta_icon         = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/openldap.svg"
  meta_launch_url   = "blank://blank"
}

resource "authentik_outpost" "ldap" {
  name               = "ldap-outpost"
  type               = "ldap"
  protocol_providers = [authentik_provider_ldap.ldap.id]
  service_connection = authentik_service_connection_docker.local.id
  config = jsonencode({
    authentik_host          = "https://auth.${local.base_domain}"
    authentik_host_insecure = false
  })
}

########################################################
# OAUTH2/OIDC PROVIDERS
########################################################
resource "random_password" "oauth2_client_secrets" {
  for_each = local.oauth2_applications

  length  = 40
  special = false
}

resource "authentik_provider_oauth2" "oauth2" {
  for_each = local.oauth2_applications

  name               = each.value.name
  client_id          = each.value.slug
  client_secret      = random_password.oauth2_client_secrets[each.key].result
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  property_mappings  = data.authentik_property_mapping_provider_scope.oauth2_scopes.ids
  signing_key        = data.authentik_certificate_key_pair.generated.id

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
  slug              = each.value.slug
  protocol_provider = authentik_provider_oauth2.oauth2[each.key].id
  meta_icon         = each.value.icon_url
  meta_launch_url   = each.value.launch_url
}

########################################################
# PROXY PROVIDERS (Forward Auth via Traefik)
########################################################
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
  slug              = each.value.slug
  protocol_provider = authentik_provider_proxy.proxy[each.key].id
  meta_icon         = each.value.icon_url
  meta_launch_url   = each.value.launch_url
}

########################################################
# DASHBOARD ONLY APPLICATIONS (No authentication)
########################################################
resource "authentik_application" "dashboard" {
  for_each = local.dashboard_applications

  name            = each.value.name
  slug            = each.value.slug
  meta_icon       = each.value.icon_url
  meta_launch_url = each.value.launch_url
}

########################################################
# ACCESS CONTROL POLICIES
########################################################

# Admin group can access all OAuth2 applications
resource "authentik_policy_binding" "oauth2_admin_access" {
  for_each = local.oauth2_applications

  target = authentik_application.oauth2[each.key].uuid
  group  = authentik_group.groups["admins"].id
  order  = 0
}

# Admin group can access all proxy applications
resource "authentik_policy_binding" "proxy_admin_access" {
  for_each = local.proxy_applications

  target = authentik_application.proxy[each.key].uuid
  group  = authentik_group.groups["admins"].id
  order  = 0
}

# Admin group can access all dashboard applications
resource "authentik_policy_binding" "dashboard_admin_access" {
  for_each = local.dashboard_applications

  target = authentik_application.dashboard[each.key].uuid
  group  = authentik_group.groups["admins"].id
  order  = 0
}

# Admin group can access LDAP application
resource "authentik_policy_binding" "ldap_admin_access" {
  target = authentik_application.ldap.uuid
  group  = authentik_group.groups["admins"].id
  order  = 0
}

# Users group can access specific OAuth2 applications
resource "authentik_policy_binding" "oauth2_user_access" {
  for_each = toset([for app in local.user_accessible_apps : app if contains(keys(local.oauth2_applications), app)])

  target = authentik_application.oauth2[each.key].uuid
  group  = authentik_group.groups["users"].id
  order  = 1
}

# Users group can access specific proxy applications
resource "authentik_policy_binding" "proxy_user_access" {
  for_each = toset([for app in local.user_accessible_apps : app if contains(keys(local.proxy_applications), app)])

  target = authentik_application.proxy[each.key].uuid
  group  = authentik_group.groups["users"].id
  order  = 1
}

# Users group can access specific dashboard applications
resource "authentik_policy_binding" "dashboard_user_access" {
  for_each = toset([for app in local.user_accessible_apps : app if contains(keys(local.dashboard_applications), app)])

  target = authentik_application.dashboard[each.key].uuid
  group  = authentik_group.groups["users"].id
  order  = 1
}