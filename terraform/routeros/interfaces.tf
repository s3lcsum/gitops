# System Identity
resource "routeros_system_identity" "main" {
  name = "MikroTik-MainRouter"
}

resource "routeros_bridge" "default" {
  name           = "bridge"
  comment        = "defconf"
  vlan_filtering = false
}

# Bridge Ports
resource "routeros_bridge_port" "ether2" {
  for_each = toset([
    "ether2",
    "ether3",
    "ether4",
    "ether5",
    "wlan1",
    "wlan2",
  ])

  bridge    = routeros_bridge.default.name
  interface = each.value
}

# IP Pool
resource "routeros_ip_pool" "default" {
  name   = "defconf"
  ranges = ["192.168.89.100-192.168.89.199"]
}

# DHCP Server
resource "routeros_dhcp_server" "default" {
  name          = "defconf"
  interface     = routeros_bridge.default.name
  address_pool  = routeros_ip_pool.default.name
  lease_time    = "10m"
  bootp_support = "none"
}

resource "routeros_ip_dhcp_server_network" "default" {
  comment = "defconf"

  address        = "192.168.89.0/24"
  gateway        = "192.168.89.1"
  dns_server     = ["192.168.89.251", "1.1.1.1"]
  domain         = "home"
  boot_file_name = "netboot.xyz.kpxe"
  netmask        = 24
}

# IP Address
resource "routeros_ip_address" "main_bridge" {
  address   = "192.168.89.1/24"
  interface = routeros_bridge.default.name
  comment   = "defconf"
}

# DNS
resource "routeros_dns" "main" {
  allow_remote_requests = true
  servers               = ["192.168.89.251"]
}

# Firewall: ICMP
resource "routeros_firewall_filter" "icmp" {
  chain    = "input"
  action   = "accept"
  protocol = "icmp"
  comment  = "Allow ICMP (ping)"
}

# Firewall: Established/Related
resource "routeros_ip_firewall_filter" "established_related" {
  chain            = "input"
  action           = "accept"
  connection_state = "established,related,untracked"
  comment          = "defconf: accept established, related, untracked"
}

# Firewall: Drop non-LAN
resource "routeros_firewall_filter" "drop_non_lan" {
  chain             = "input"
  action            = "drop"
  in_interface_list = "!${routeros_interface_list.lan.name}"
  comment           = "defconf: drop all not coming from LAN"
  log               = true
  log_prefix        = "Firewall-Drop (non-LAN): "
}

# NAT: Masquerade
resource "routeros_firewall_nat" "masquerade" {
  chain              = "srcnat"
  action             = "masquerade"
  out_interface_list = routeros_interface_list.wan.name
  comment            = "defconf: masquerade"
}

# Interface Lists
resource "routeros_interface_list" "wan" {
  name    = "WAN"
  comment = "defconf"
}

resource "routeros_interface_list" "lan" {
  name    = "LAN"
  comment = "defconf"
}

resource "routeros_interface_list_member" "bridge_lan" {
  interface = routeros_bridge.default.name
  list      = routeros_interface_list.lan.name
}

resource "routeros_interface_list_member" "lan" {
  for_each = toset([
    "ether2",
    "ether3",
    "ether4",
    "ether5",
    "wlan1",
    "wlan2",
    routeros_bridge.default.name,
  ])

  interface = each.value
  list      = routeros_interface_list.lan.name
}

resource "routeros_interface_list_member" "wan" {
  interface = "ether1"
  list      = routeros_interface_list.wan.name
}
