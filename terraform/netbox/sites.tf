# Create DC-0 (Jarocin) site
resource "netbox_site" "dc0_jarocin" {
  name        = "DC-0 (Jarocin)"
  slug        = "dc0-jarocin"
  description = "Home laboratory infrastructure - Jarocin"
  status      = "active"

  tags = [
    netbox_tag.homelab.name,
    netbox_tag.infrastructure.name
  ]
}

# Create DC-1 (Wrocław) site
resource "netbox_site" "dc1_wroclaw" {
  name        = "DC-1 (Wrocław)"
  slug        = "dc1-wroclaw"
  description = "Secondary data center - Wrocław"
  status      = "active"

  tags = [
    netbox_tag.homelab.name,
    netbox_tag.infrastructure.name
  ]
}

# Create locations for DC-0 (Jarocin)
resource "netbox_location" "dc0_server_room" {
  name        = "Server Room"
  slug        = "dc0-server-room"
  description = "Main server room with rack and networking equipment - DC-0"
  site_id     = netbox_site.dc0_jarocin.id

  tags = [netbox_tag.infrastructure.name]
}

resource "netbox_location" "dc0_network_closet" {
  name        = "Network Closet"
  slug        = "dc0-network-closet"
  description = "Network equipment closet - DC-0"
  site_id     = netbox_site.dc0_jarocin.id

  tags = [netbox_tag.infrastructure.name]
}

# Create locations for DC-1 (Wrocław)
resource "netbox_location" "dc1_server_room" {
  name        = "Server Room"
  slug        = "dc1-server-room"
  description = "Server room - DC-1"
  site_id     = netbox_site.dc1_wroclaw.id

  tags = [netbox_tag.infrastructure.name]
}
