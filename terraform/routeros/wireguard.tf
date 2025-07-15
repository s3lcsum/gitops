# WireGuard VPN Configuration for Multi-Site Mesh Network
# Creates secure tunnels between homelab sites and cloud infrastructure
#
# Network Architecture:
# - Site 1 (Current): 192.168.89.0/24
# - Site 2 (Remote House): 192.168.90.0/24 (via WireGuard)
# - Cloud Infrastructure: 10.0.0.0/16 (via WireGuard)
# - WireGuard Network: 10.100.0.0/24
#
# This configuration creates:
# 1. WireGuard interface on the router
# 2. Peer configurations for remote sites
# 3. Routing for mesh connectivity
# 4. Firewall rules for WireGuard traffic

# WireGuard Interface
resource "routeros_interface_wireguard" "wg_mesh" {
  count       = var.enable_wireguard ? 1 : 0
  name        = "wg-mesh"
  listen_port = var.wireguard_listen_port
  private_key = var.wireguard_private_key
  comment     = "WireGuard mesh network interface"
}

# IP Address for WireGuard Interface
resource "routeros_ip_address" "wg_mesh_ip" {
  count     = var.enable_wireguard ? 1 : 0
  address   = "${var.wireguard_local_ip}/${var.wireguard_network_prefix}"
  interface = routeros_interface_wireguard.wg_mesh[0].name
  comment   = "WireGuard mesh network IP"
}

# WireGuard Peers Configuration
resource "routeros_interface_wireguard_peer" "mesh_peers" {
  for_each = var.enable_wireguard ? var.wireguard_peers : {}

  interface       = routeros_interface_wireguard.wg_mesh[0].name
  public_key      = each.value.public_key
  allowed_address = each.value.allowed_ips
  comment         = each.value.comment

  # Optional persistent keepalive for NAT traversal
  persistent_keepalive = lookup(each.value, "persistent_keepalive", null)

  # Endpoint configuration (if provided)
  endpoint_address = each.value.endpoint != "" ? split(":", each.value.endpoint)[0] : null
  endpoint_port    = each.value.endpoint != "" ? tonumber(split(":", each.value.endpoint)[1]) : null
}

# Add WireGuard interface to interface lists
resource "routeros_interface_list" "wireguard" {
  count   = var.enable_wireguard ? 1 : 0
  name    = "WIREGUARD"
  comment = "WireGuard VPN interfaces"
}

resource "routeros_interface_list_member" "wg_mesh" {
  count     = var.enable_wireguard ? 1 : 0
  interface = routeros_interface_wireguard.wg_mesh[0].name
  list      = routeros_interface_list.wireguard[0].name
}

# Static Routes for Remote Networks
resource "routeros_ip_route" "wireguard_routes" {
  for_each = var.enable_wireguard ? var.wireguard_routes : {}

  dst_address = each.value.destination
  gateway     = each.value.gateway
  comment     = each.value.comment
  distance    = lookup(each.value, "distance", 1)
}

# Firewall Rules for WireGuard

# Allow WireGuard traffic on WAN interface
resource "routeros_firewall_filter" "wireguard_wan" {
  count             = var.enable_wireguard ? 1 : 0
  chain             = "input"
  action            = "accept"
  protocol          = "udp"
  dst_port          = tostring(var.wireguard_listen_port)
  in_interface_list = routeros_interface_list.wan.name
  comment           = "Allow WireGuard VPN traffic"
}

# Allow traffic from WireGuard peers
resource "routeros_firewall_filter" "wireguard_input" {
  count             = var.enable_wireguard ? 1 : 0
  chain             = "input"
  action            = "accept"
  in_interface_list = routeros_interface_list.wireguard[0].name
  comment           = "Allow input from WireGuard peers"
}

# Allow forwarding between WireGuard and LAN
resource "routeros_firewall_filter" "wireguard_forward_to_lan" {
  count              = var.enable_wireguard ? 1 : 0
  chain              = "forward"
  action             = "accept"
  in_interface_list  = routeros_interface_list.wireguard[0].name
  out_interface_list = routeros_interface_list.lan.name
  comment            = "Allow WireGuard to LAN forward"
}

resource "routeros_firewall_filter" "lan_forward_to_wireguard" {
  count              = var.enable_wireguard ? 1 : 0
  chain              = "forward"
  action             = "accept"
  in_interface_list  = routeros_interface_list.lan.name
  out_interface_list = routeros_interface_list.wireguard[0].name
  comment            = "Allow LAN to WireGuard forward"
}

# Allow forwarding between WireGuard peers (mesh connectivity)
resource "routeros_firewall_filter" "wireguard_mesh_forward" {
  count              = var.enable_wireguard ? 1 : 0
  chain              = "forward"
  action             = "accept"
  in_interface_list  = routeros_interface_list.wireguard[0].name
  out_interface_list = routeros_interface_list.wireguard[0].name
  comment            = "Allow WireGuard mesh forwarding"
}

# NAT Rules for WireGuard (if needed for internet access from remote sites)
resource "routeros_firewall_nat" "wireguard_masquerade" {
  count              = var.enable_wireguard && var.wireguard_enable_nat ? 1 : 0
  chain              = "srcnat"
  action             = "masquerade"
  out_interface_list = routeros_interface_list.wan.name
  src_address        = var.wireguard_network_cidr
  comment            = "Masquerade WireGuard traffic to WAN"
}

# Optional: DNS forwarding for remote sites
resource "routeros_firewall_filter" "wireguard_dns" {
  count             = var.enable_wireguard ? 1 : 0
  chain             = "input"
  action            = "accept"
  protocol          = "udp"
  dst_port          = "53"
  in_interface_list = routeros_interface_list.wireguard[0].name
  comment           = "Allow DNS queries from WireGuard peers"
}
