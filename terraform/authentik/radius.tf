# RouterOS device admin login via Authentik RADIUS.
# RouterOS only supports RADIUS (not OIDC/LDAP) for WinBox/SSH/WebFig auth.
# The Authentik RADIUS outpost publishes UDP 1812/1813 on the Portainer LXC
# (192.168.89.253); the router reaches it over the LAN.

resource "authentik_flow" "routeros_authentication" {
  name               = "routeros-authentication-flow"
  title              = "RouterOS Authentication"
  slug               = "routeros-authentication-flow"
  designation        = "authentication"
  policy_engine_mode = "any"
}

resource "authentik_stage_identification" "routeros_identification" {
  name               = "routeros-identification"
  user_fields        = ["username", "email"]
  show_source_labels = false
}

resource "authentik_stage_password" "routeros_password" {
  name     = "routeros-password"
  backends = ["authentik.core.auth.InbuiltBackend"]
}

resource "authentik_stage_user_login" "routeros_login" {
  name                     = "routeros-login"
  session_duration         = "seconds=0"
  terminate_other_sessions = false
}

resource "authentik_flow_stage_binding" "routeros" {
  for_each = {
    identification = { stage = authentik_stage_identification.routeros_identification.id, order = 10 }
    password       = { stage = authentik_stage_password.routeros_password.id, order = 20 }
    login          = { stage = authentik_stage_user_login.routeros_login.id, order = 30 }
  }

  target = authentik_flow.routeros_authentication.uuid
  stage  = each.value.stage
  order  = each.value.order
}

resource "random_password" "routeros_radius_secret" {
  length  = 32
  special = false
}

resource "authentik_provider_radius" "routeros" {
  name               = "routeros"
  shared_secret      = random_password.routeros_radius_secret.result
  authorization_flow = authentik_flow.routeros_authentication.uuid
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  # Only accept RADIUS requests originating from the LAN (router source IP).
  client_networks = "192.168.89.0/24"

  property_mappings = [
    authentik_property_mapping_provider_radius.routeros_group.id,
  ]
}

# Return the MikroTik VSA "Group" = "full" for admins so RouterOS grants full policy.
resource "authentik_property_mapping_provider_radius" "routeros_group" {
  name       = "routeros-group"
  expression = <<-EOF
    define_attribute(
      vendor_code     = 14988,
      vendor_name     = "Mikrotik",
      attribute_name  = "Group",
      attribute_code = 3,
      attribute_type = "string",
    )
    packet = {}
    if request.user.ak_groups.filter(name="admins").exists():
        packet["Mikrotik-Group"] = "full"
    return packet
  EOF
}

resource "authentik_application" "routeros" {
  name              = "RouterOS"
  slug              = "routeros"
  protocol_provider = authentik_provider_radius.routeros.id
  meta_icon         = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/mikrotik.svg"
  meta_launch_url   = "blank://blank"
}

resource "authentik_outpost" "radius" {
  name               = "radius-outpost"
  type               = "radius"
  protocol_providers = [authentik_provider_radius.routeros.id]
  service_connection = authentik_service_connection_docker.local.id
  config = jsonencode({
    authentik_host          = "https://auth.${local.base_domain}"
    authentik_host_insecure = false
  })
}

resource "authentik_policy_binding" "routeros_admin_access" {
  target = authentik_application.routeros.uuid
  group  = authentik_group.admins.id
  order  = 0
}

output "radius" {
  description = "RADIUS config for RouterOS admin login (consumed by terraform/routeros)."
  value = {
    host      = "192.168.89.253"
    auth_port = 1812
    secret    = random_password.routeros_radius_secret.result
  }
  sensitive = true
}
