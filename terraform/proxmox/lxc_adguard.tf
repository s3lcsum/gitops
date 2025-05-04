resource "proxmox_virtual_environment_container" "adguard" {
  node_name = data.proxmox_virtual_environment_nodes.all_nodes.names[0]

  start_on_boot = true
  protection    = false
  unprivileged  = true

  description = ""

  tags = ["gitops"]

  disk {
    datastore_id = "local-lvm"
    size         = 2
  }

  memory {
    dedicated = 512
    swap      = 512
  }

  network_interface {
    bridge = "vmbr0"
    name   = "eth0"
  }

  operating_system {
    type             = "debian"
    template_file_id = "" # Can't be imported, so we need to use the template_file_id from the image resource
    # template_file_id = proxmox_virtual_environment_download_file.latest_debian_12_standard_lxc_img.id
  }

  initialization {
    hostname = "adguard"


    dns {
      domain  = "home"
      servers = ["127.0.0.1"]
    }

    ip_config {
      ipv4 {
        address = "192.168.89.251/24"
        gateway = "192.168.89.1"
      }

      ipv6 {
        address = "fd00::4/64"
        gateway = "fd00::1"
      }
    }
  }
}
