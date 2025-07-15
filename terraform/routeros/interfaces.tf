# Bridge Configuration
resource "routeros_bridge" "default" {
  name           = "bridge"
  comment        = "defconf"
  vlan_filtering = false
}

# Bridge Ports - Connect physical interfaces to bridge
resource "routeros_bridge_port" "lan_ports" {
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
  comment   = "LAN port ${each.value}"
}

# IP Address for Bridge (Gateway)
resource "routeros_ip_address" "main_bridge" {
  address   = "${var.gateway_ip}/24"
  interface = routeros_bridge.default.name
  comment   = "defconf"
}

# DNS Configuration
resource "routeros_dns" "main" {
  allow_remote_requests = false
  servers               = var.dns_servers
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
