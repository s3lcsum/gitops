# Device roles for different types of infrastructure
resource "netbox_device_role" "hypervisor" {
  name        = "Hypervisor"
  slug        = "hypervisor"
  description = "Proxmox hypervisor nodes"
  color_hex   = "2196f3"
  vm_role     = false

  tags = [
    netbox_tag.proxmox.name,
    netbox_tag.infrastructure.name
  ]
}

resource "netbox_device_role" "container_host" {
  name        = "Container Host"
  slug        = "container-host"
  description = "LXC container host"
  color_hex   = "4caf50"
  vm_role     = true

  tags = [
    netbox_tag.lxc.name,
    netbox_tag.infrastructure.name
  ]
}

resource "netbox_device_role" "virtual_machine" {
  name        = "Virtual Machine"
  slug        = "virtual-machine"
  description = "Virtual machine instances"
  color_hex   = "ff9800"
  vm_role     = true

  tags = [
    netbox_tag.vm.name
  ]
}

resource "netbox_device_role" "kubernetes_node" {
  name        = "Kubernetes Node"
  slug        = "kubernetes-node"
  description = "Kubernetes cluster nodes"
  color_hex   = "326ce5"
  vm_role     = true

  tags = [
    netbox_tag.kubernetes.name,
    netbox_tag.vm.name
  ]
}

resource "netbox_device_role" "network_device" {
  name        = "Network Device"
  slug        = "network-device"
  description = "Network switches, routers, and access points"
  color_hex   = "607d8b"
  vm_role     = false

  tags = [
    netbox_tag.network.name,
    netbox_tag.infrastructure.name
  ]
}

resource "netbox_device_role" "storage_device" {
  name        = "Storage Device"
  slug        = "storage-device"
  description = "NAS and storage systems"
  color_hex   = "795548"
  vm_role     = false

  tags = [
    netbox_tag.storage.name,
    netbox_tag.infrastructure.name
  ]
}

resource "netbox_device_role" "dns_server" {
  name        = "DNS Server"
  slug        = "dns-server"
  description = "DNS and DHCP servers"
  color_hex   = "00bcd4"
  vm_role     = true

  tags = [
    netbox_tag.dns.name,
    netbox_tag.lxc.name
  ]
}

resource "netbox_device_role" "database_server" {
  name        = "Database Server"
  slug        = "database-server"
  description = "Database servers"
  color_hex   = "3f51b5"
  vm_role     = true

  tags = [
    netbox_tag.database.name,
    netbox_tag.lxc.name
  ]
}

resource "netbox_device_role" "router" {
  name        = "Router"
  slug        = "router"
  description = "Network routers and gateways"
  color_hex   = "9c27b0"
  vm_role     = false

  tags = [
    netbox_tag.network.name,
    netbox_tag.infrastructure.name
  ]
}

resource "netbox_device_role" "access_point" {
  name        = "Access Point"
  slug        = "access-point"
  description = "Wireless access points"
  color_hex   = "ff5722"
  vm_role     = false

  tags = [
    netbox_tag.network.name,
    netbox_tag.infrastructure.name
  ]
}

resource "netbox_device_role" "printer" {
  name        = "Printer"
  slug        = "printer"
  description = "Network printers and multifunction devices"
  color_hex   = "607d8b"
  vm_role     = false

  tags = [
    netbox_tag.infrastructure.name
  ]
}

resource "netbox_device_role" "iot_device" {
  name        = "IoT Device"
  slug        = "iot-device"
  description = "Internet of Things devices"
  color_hex   = "8bc34a"
  vm_role     = false

  tags = [
    netbox_tag.infrastructure.name
  ]
}

resource "netbox_device_role" "wireguard_client" {
  name        = "WireGuard Client"
  slug        = "wireguard-client"
  description = "WireGuard VPN clients"
  color_hex   = "2196f3"
  vm_role     = false

  tags = [
    netbox_tag.network.name
  ]
}
