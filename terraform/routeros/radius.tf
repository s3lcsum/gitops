# RADIUS Configuration for Keycloak/FreeRADIUS Authentication
#
# This configures RouterOS to use an external RADIUS server for authentication.
# The RADIUS server connects to OpenLDAP, which is federated with Keycloak.
# This enables centralized authentication for RouterOS admin access.

resource "routeros_radius" "external" {
  count = var.enable_radius ? 1 : 0

  address          = var.radius_server
  secret           = var.radius_secret
  timeout          = "${var.radius_timeout}ms"
  service          = ["login"]
  authentication_port = 1812
  accounting_port     = 1813

  comment = "FreeRADIUS for Keycloak authentication"
}

# Enable RADIUS authentication for user login
resource "routeros_system_user_aaa" "radius_auth" {
  count = var.enable_radius ? 1 : 0

  use_radius         = true
  accounting         = true
  interim_update     = "0s"
  default_group      = "read"
  exclude_groups     = []
}

