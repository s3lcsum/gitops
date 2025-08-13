# Create the main homelab site
resource "netbox_site" "homelab" {
  name        = var.site_name
  slug        = "homelab"
  description = "Home laboratory infrastructure"
  status      = "active"

  tags = [
    netbox_tag.homelab.name,
    netbox_tag.infrastructure.name
  ]
}

# Create locations within the site
resource "netbox_location" "server_room" {
  name        = "Server Room"
  slug        = "server-room"
  description = "Main server room with rack and networking equipment"
  site_id     = netbox_site.homelab.id

  tags = [netbox_tag.infrastructure.name]
}

resource "netbox_location" "network_closet" {
  name        = "Network Closet"
  slug        = "network-closet"
  description = "Network equipment closet"
  site_id     = netbox_site.homelab.id

  tags = [netbox_tag.infrastructure.name]
}
