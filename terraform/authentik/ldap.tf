resource "authentik_service_connection_docker" "local" {
  name  = "docker-local"
  local = true
}

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

resource "authentik_flow_stage_binding" "ldap" {
  for_each = {
    identification = { stage = authentik_stage_identification.ldap_identification.id, order = 10 }
    password       = { stage = authentik_stage_password.ldap_password.id, order = 20 }
    login          = { stage = authentik_stage_user_login.ldap_login.id, order = 30 }
  }

  target = authentik_flow.ldap_authentication.uuid
  stage  = each.value.stage
  order  = each.value.order
}

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

resource "authentik_policy_binding" "ldap_admin_access" {
  target = authentik_application.ldap.uuid
  group  = authentik_group.admins.id
  order  = 0
}
