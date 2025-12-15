# IP Addresses for all devices

# DC-0 (Jarocin) - Routers
resource "netbox_ip_address" "dc0_main_router" {
  ip_address  = "192.168.89.1/24"
  description = "Main Router - DC-0"
  status      = "active"

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.router.name
  ]
}

resource "netbox_ip_address" "dc0_second_router" {
  ip_address  = "192.168.89.116/24"
  description = "Second Router - DC-0"
  status      = "active"
  tags = [
    netbox_tag.dc0.name,
    netbox_tag.router.name
  ]
}

# DC-0 (Jarocin) - Access Points
resource "netbox_ip_address" "dc0_ap_0" {
  ip_address  = "192.168.89.10/24"
  description = "Access Point 0 (Tp-Link Deco) - DC-0"
  status      = "active"
  tags = [
    netbox_tag.dc0.name,
    netbox_tag.access_point.name
  ]
}

resource "netbox_ip_address" "dc0_ap_1" {
  ip_address  = "192.168.89.11/24"
  description = "Access Point 1 (Tp-Link Deco) - DC-0"
  status      = "active"
  tags = [
    netbox_tag.dc0.name,
    netbox_tag.access_point.name
  ]
}

resource "netbox_ip_address" "dc0_ap_2" {
  ip_address  = "192.168.89.12/24"
  description = "Access Point 2 (Tp-Link Deco) - DC-0"
  status      = "active"
  tags = [
    netbox_tag.dc0.name,
    netbox_tag.access_point.name
  ]
}

# DC-0 (Jarocin) - Printer
resource "netbox_ip_address" "dc0_printer" {
  ip_address  = "192.168.89.55/24"
  description = "Sharp MX-4071 Printer - DC-0"
  status      = "active"
  tags = [
    netbox_tag.dc0.name,
    netbox_tag.printer.name
  ]
}

# DC-0 (Jarocin) - IoT Device
resource "netbox_ip_address" "dc0_zbbridge" {
  ip_address  = "192.168.89.20/24"
  description = "Tasmota Sonoff ZBBridge Pro - DC-0"
  status      = "active"
  tags = [
    netbox_tag.dc0.name,
    netbox_tag.iot.name
  ]
}

# DC-0 (Jarocin) - Servers
resource "netbox_ip_address" "dc0_rpi_1" {
  ip_address  = "192.168.89.206/24"
  description = "Raspberry Pi 1 - DC-0"
  status      = "active"
  tags = [
    netbox_tag.dc0.name,
    netbox_tag.infrastructure.name
  ]
}

resource "netbox_ip_address" "dc0_home_assistant" {
  ip_address  = "192.168.89.251/24"
  description = "Home Assistant - DC-0"
  status      = "active"
  tags = [
    netbox_tag.dc0.name,
    netbox_tag.infrastructure.name
  ]
}

resource "netbox_ip_address" "dc0_portainer" {
  ip_address  = "192.168.89.253/24"
  description = "Portainer (HomeLab VM) - DC-0"
  status      = "active"
  tags = [
    netbox_tag.dc0.name,
    netbox_tag.vm.name
  ]
}

resource "netbox_ip_address" "dc0_lake_1" {
  ip_address  = "192.168.89.254/24"
  description = "Lake-1 (HomeLab Host) - DC-0"
  status      = "active"
  tags = [
    netbox_tag.dc0.name,
    netbox_tag.proxmox.name
  ]
}

# DC-0 (Jarocin) - WireGuard Clients
resource "netbox_ip_address" "wg_dominik_ipad" {
  ip_address  = "192.168.200.23/24"
  description = "Dominik's iPad (WireGuard) - DC-0"
  status      = "active"

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.wireguard.name
  ]
}

resource "netbox_ip_address" "wg_dominik_macbook" {
  ip_address  = "192.168.200.20/24"
  description = "Dominik's MacBook (WireGuard) - DC-0"
  status      = "active"

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.wireguard.name
  ]
}

resource "netbox_ip_address" "wg_jasiejak_iphone" {
  ip_address  = "192.168.200.31/24"
  description = "Jasiejak's iPhone (WireGuard) - DC-0"
  status      = "active"

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.wireguard.name
  ]
}

resource "netbox_ip_address" "wg_jasiejak_macbook" {
  ip_address  = "192.168.200.32/24"
  description = "Jasiejak's MacBook (WireGuard) - DC-0"
  status      = "active"

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.wireguard.name
  ]
}

# DC-1 (Wrocław) - Router
resource "netbox_ip_address" "dc1_main_router" {
  ip_address  = "192.168.8.1/24"
  description = "Main Router - DC-1"
  status      = "active"
  tags = [
    netbox_tag.dc1.name,
    netbox_tag.router.name
  ]
}

# DC-1 (Wrocław) - Servers
resource "netbox_ip_address" "dc1_atom_1" {
  ip_address  = "192.168.8.254/24"
  description = "Atom-1 (Homelab Server) - DC-1"
  status      = "active"
  tags = [
    netbox_tag.dc1.name,
    netbox_tag.proxmox.name
  ]
}

resource "netbox_ip_address" "dc1_portainer_2" {
  ip_address  = "192.168.8.253/24"
  description = "Portainer-2 - DC-1"
  status      = "active"
  tags = [
    netbox_tag.dc1.name,
    netbox_tag.vm.name
  ]
}
