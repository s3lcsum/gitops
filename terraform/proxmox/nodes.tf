data "proxmox_virtual_environment_nodes" "all_nodes" {}

resource "proxmox_virtual_environment_dns" "default" {
  for_each  = toset(data.proxmox_virtual_environment_nodes.all_nodes.names)
  node_name = each.value

  domain = "home"
  servers = [
    "192.168.89.251", # LXC: adguard
    "fd89:1::53",     # LXC: adguard
    "1.1.1.1",
  ]
}


resource "proxmox_virtual_environment_time" "first_node_time" {
  for_each  = toset(data.proxmox_virtual_environment_nodes.all_nodes.names)
  node_name = each.value

  time_zone = "UTC"
}

resource "proxmox_virtual_environment_vm" "k3s_node" {
  node_name = data.proxmox_virtual_environment_nodes.all_nodes.names[0]
  name      = "k3s-node-01"
  vm_id     = 100

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.ubuntu_22_04_cloud_img.id
    interface    = "virtio0"
    size         = 40
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.89.100/24"
        gateway = "192.168.89.1"
      }
      ipv6 {
        address = "fd89:2::100/64"
        gateway = "fd89:2::1"
      }
    }

    dns {
      domain  = "wally.dominiksiejak.pl"
      servers = ["192.168.89.251", "fd89:1::53"]
    }

    user_account {
      username = "ubuntu"
      keys     = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC..."] # Add your SSH public key here
    }
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  vga {
    type = "serial0"
  }
}
