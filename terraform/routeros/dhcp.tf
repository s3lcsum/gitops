# IP Pool for DHCP
resource "routeros_ip_pool" "default" {
  name   = "defconf"
  ranges = ["${var.dhcp_pool_start}-${var.dhcp_pool_end}"]
}

# DHCP Server
resource "routeros_dhcp_server" "default" {
  name          = "defconf"
  interface     = "bridge"
  address_pool  = routeros_ip_pool.default.name
  lease_time    = "10m"
  bootp_support = "none"
}

# DHCP Server Network Configuration
resource "routeros_dhcp_server_network" "default" {
  comment = "defconf"

  address        = var.network_cidr
  gateway        = var.gateway_ip
  dns_server     = var.dns_servers
  domain         = var.domain_name
  boot_file_name = "netboot.xyz.kpxe"
  netmask        = 24
}
