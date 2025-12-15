# IP Prefixes for network subnets

# DC-0 (Jarocin) - Main local network
resource "netbox_prefix" "dc0_local" {
  prefix      = "192.168.89.0/24"
  description = "DC-0 Local Network - Jarocin"
  is_pool     = false
  status      = "active"
  site_id     = netbox_site.dc0_jarocin.id

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.network.name
  ]
}

# DC-0 (Jarocin) - DHCP pool
resource "netbox_prefix" "dc0_dhcp" {
  prefix      = "192.168.89.100/25" # 192.168.89.100-199 (DHCP range)
  description = "DC-0 DHCP Pool - Jarocin"
  is_pool     = true
  status      = "active"
  site_id     = netbox_site.dc0_jarocin.id

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.network.name
  ]
}

# DC-0 (Jarocin) - WireGuard network
resource "netbox_prefix" "dc0_wireguard" {
  prefix      = "192.168.200.0/24"
  description = "DC-0 WireGuard VPN Network"
  is_pool     = false
  status      = "active"
  site_id     = netbox_site.dc0_jarocin.id

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.wireguard.name,
    netbox_tag.network.name
  ]
}

# DC-1 (Wrocław) - Main local network
resource "netbox_prefix" "dc1_local" {
  prefix      = "192.168.8.0/24"
  description = "DC-1 Local Network - Wrocław"
  is_pool     = false
  status      = "active"
  site_id     = netbox_site.dc1_wroclaw.id

  tags = [
    netbox_tag.dc1.name,
    netbox_tag.network.name
  ]
}
