# System Identity
resource "routeros_system_identity" "main" {
  name = var.router_identity
}

# NTP Client Configuration
resource "routeros_system_ntp_client" "main" {
  enabled = true
  mode    = "unicast"
  servers = var.ntp_servers
}

# Note: User management is not supported by the RouterOS provider
# Users must be configured manually via RouterOS interface:
# - admin: Full administrative access
# - metrics: Read-only access for monitoring systems

# System Logging
resource "routeros_system_logging" "info" {
  topics = ["info"]
  action = "memory"
}

resource "routeros_system_logging" "error" {
  topics = ["error"]
  action = "memory"
}

resource "routeros_system_logging" "warning" {
  topics = ["warning"]
  action = "memory"
}

# System Clock
resource "routeros_system_clock" "main" {
  time_zone_name = "Europe/Warsaw"
}

# SNMP Configuration for metrics collection
resource "routeros_snmp" "main" {
  enabled  = true
  contact  = "homelab-admin"
  location = "Home Lab"
}
