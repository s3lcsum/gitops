# Create tags for organizing resources
resource "netbox_tag" "homelab" {
  name        = "homelab"
  slug        = "homelab"
  description = "Homelab infrastructure"
}

resource "netbox_tag" "infrastructure" {
  name        = "infrastructure"
  slug        = "infrastructure"
  description = "Core infrastructure components"
}

resource "netbox_tag" "proxmox" {
  name        = "proxmox"
  slug        = "proxmox"
  description = "Proxmox virtualization platform"
}

resource "netbox_tag" "kubernetes" {
  name        = "kubernetes"
  slug        = "kubernetes"
  description = "Kubernetes cluster components"
}

resource "netbox_tag" "lxc" {
  name        = "lxc"
  slug        = "lxc"
  description = "LXC containers"
}

resource "netbox_tag" "vm" {
  name        = "vm"
  slug        = "vm"
  description = "Virtual machines"
}

resource "netbox_tag" "network" {
  name        = "network"
  slug        = "network"
  description = "Network equipment"
}

resource "netbox_tag" "storage" {
  name        = "storage"
  slug        = "storage"
  description = "Storage systems"
}

resource "netbox_tag" "monitoring" {
  name        = "monitoring"
  slug        = "monitoring"
  description = "Monitoring and observability"
}

resource "netbox_tag" "dns" {
  name        = "dns"
  slug        = "dns"
  description = "DNS services"
}

resource "netbox_tag" "database" {
  name        = "database"
  slug        = "database"
  description = "Database services"
}

resource "netbox_tag" "router" {
  name        = "router"
  slug        = "router"
  description = "Router devices"
}

resource "netbox_tag" "access_point" {
  name        = "access-point"
  slug        = "access-point"
  description = "Wireless access points"
}

resource "netbox_tag" "printer" {
  name        = "printer"
  slug        = "printer"
  description = "Printer devices"
}

resource "netbox_tag" "iot" {
  name        = "iot"
  slug        = "iot"
  description = "Internet of Things devices"
}

resource "netbox_tag" "wireguard" {
  name        = "wireguard"
  slug        = "wireguard"
  description = "WireGuard VPN"
}

resource "netbox_tag" "dc0" {
  name        = "dc0"
  slug        = "dc0"
  description = "Data Center 0 (Jarocin)"
}

resource "netbox_tag" "dc1" {
  name        = "dc1"
  slug        = "dc1"
  description = "Data Center 1 (Wrocław)"
}
