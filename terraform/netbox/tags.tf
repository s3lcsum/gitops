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
