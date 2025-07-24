resource "proxmox_virtual_environment_container" "this" {
  node_name     = var.node_name
  start_on_boot = true
  protection    = false
  unprivileged  = true

  disk {
    datastore_id = var.disk.datastore_id
    size         = var.disk.size
  }

  memory {
    dedicated = var.memory.dedicated
    swap      = var.memory.swap
  }

  network_interface {
    bridge = var.network_interface.bridge
    name   = var.network_interface.name
  }

  operating_system {
    type             = var.os_type
    template_file_id = var.template_file_id
  }

  initialization {
    hostname = var.hostname
    ip_config {
      ipv4 {
        address = var.ip_config.ipv4.address
        gateway = var.ip_config.ipv4.gateway
      }
      ipv6 {
        address = var.ip_config.ipv6.address
        gateway = var.ip_config.ipv6.gateway
      }
    }
    dynamic "dns" {
      for_each = var.dns == null ? [] : [var.dns]
      content {
        domain  = dns.value.domain
        servers = dns.value.servers
      }
    }
  }

  dynamic "mount_point" {
    for_each = var.mount_points
    content {
      volume = mount_point.value.volume
      path   = mount_point.value.path
    }
  }
}
