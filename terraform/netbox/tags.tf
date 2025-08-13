# Create tags for organizing resources
resource "netbox_tag" "homelab" {
  name        = "homelab"
  slug        = "homelab"
  description = "Homelab infrastructure"
  color       = "2196f3"
}

resource "netbox_tag" "infrastructure" {
  name        = "infrastructure"
  slug        = "infrastructure"
  description = "Core infrastructure components"
  color       = "9c27b0"
}

resource "netbox_tag" "proxmox" {
  name        = "proxmox"
  slug        = "proxmox"
  description = "Proxmox virtualization platform"
  color       = "ff5722"
}

resource "netbox_tag" "kubernetes" {
  name        = "kubernetes"
  slug        = "kubernetes"
  description = "Kubernetes cluster components"
  color       = "326ce5"
}

resource "netbox_tag" "lxc" {
  name        = "lxc"
  slug        = "lxc"
  description = "LXC containers"
  color       = "4caf50"
}

resource "netbox_tag" "vm" {
  name        = "vm"
  slug        = "vm"
  description = "Virtual machines"
  color       = "ff9800"
}

resource "netbox_tag" "network" {
  name        = "network"
  slug        = "network"
  description = "Network equipment"
  color       = "607d8b"
}

resource "netbox_tag" "storage" {
  name        = "storage"
  slug        = "storage"
  description = "Storage systems"
  color       = "795548"
}

resource "netbox_tag" "monitoring" {
  name        = "monitoring"
  slug        = "monitoring"
  description = "Monitoring and observability"
  color       = "e91e63"
}

resource "netbox_tag" "dns" {
  name        = "dns"
  slug        = "dns"
  description = "DNS services"
  color       = "00bcd4"
}

resource "netbox_tag" "database" {
  name        = "database"
  slug        = "database"
  description = "Database services"
  color       = "3f51b5"
}
