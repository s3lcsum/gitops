# Download Talos OS image from GitHub releases
# This downloads the nocloud image which is pre-configured for cloud-init
resource "proxmox_virtual_environment_download_file" "talos_os_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = data.proxmox_virtual_environment_nodes.all_nodes.names[0]
  url          = "https://factory.talos.dev/image/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515/v1.10.6/metal-amd64.iso"
  file_name    = "talos-metal-amd64.iso"
}

# Control Plane VM - Kubernetes master node
# This VM will run the Kubernetes control plane components
resource "proxmox_virtual_environment_vm" "control" {
  node_name = data.proxmox_virtual_environment_nodes.all_nodes.names[0]
  name      = local.control_plane.name
  vm_id     = local.control_plane.vm_id

  # CPU configuration - using host passthrough for better performance
  cpu {
    cores = local.control_plane.cpu_cores
    type  = "host"
  }

  # Memory configuration
  memory {
    dedicated = local.control_plane.memory_mb
  }

  # Disk configuration - uses the downloaded Talos image
  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.talos_os_image.id
    interface    = "virtio0"
    size         = local.control_plane.disk_gb
  }

  # Network configuration - connects to default bridge
  network_device {
    bridge = "vmbr0"
  }

  # Cloud-init configuration for network and DNS settings
  initialization {
    ip_config {
      ipv4 {
        address = "${local.control_ip}/${split("/", local.network_cidr)[1]}"
        gateway = local.network_gateway
      }
    }
    dns {
      domain  = var.domain
      servers = var.dns_servers
    }
  }

  # OS type for Linux 2.6+ kernel
  operating_system {
    type = "l26"
  }

  # Enable serial console for debugging
  serial_device {}
  vga {
    type = "serial0"
  }
}

# Worker VMs - Kubernetes worker nodes
# These VMs will run the application workloads and join the cluster
resource "proxmox_virtual_environment_vm" "workers" {
  for_each = local.workers

  node_name = data.proxmox_virtual_environment_nodes.all_nodes.names[0]
  name      = each.key
  vm_id     = each.value.vm_id

  # CPU configuration - using host passthrough for better performance
  cpu {
    cores = each.value.cpu_cores
    type  = "host"
  }

  # Memory configuration
  memory {
    dedicated = each.value.memory_mb
  }

  # Disk configuration - uses the same Talos image as control plane
  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.talos_os_image.id
    interface    = "virtio0"
    size         = each.value.disk_gb
  }

  # Network configuration - connects to default bridge
  network_device {
    bridge = "vmbr0"
  }

  # Cloud-init configuration with unique IP per worker
  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip}/${split("/", local.network_cidr)[1]}"
        gateway = local.network_gateway
      }
    }
    dns {
      domain  = var.domain
      servers = var.dns_servers
    }
  }

  # OS type for Linux 2.6+ kernel
  operating_system {
    type = "l26"
  }

  # Enable serial console for debugging
  serial_device {}
  vga {
    type = "serial0"
  }
}
