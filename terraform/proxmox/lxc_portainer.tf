resource "proxmox_virtual_environment_container" "portainer" {
  node_name = data.proxmox_virtual_environment_nodes.all_nodes.names[0]

  start_on_boot = true
  protection    = false
  unprivileged  = true

  description = ""

  tags = ["gitops"]

  disk {
    datastore_id = "local-lvm"
    size         = 40
  }

  memory {
    dedicated = 4096
    swap      = 0
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
    hostname = "portainer"

    ip_config {
      ipv4 {
        address = "192.168.89.253/24"
        gateway = "192.168.89.1"
      }

      ipv6 {
        address = "fd00::3/64"
        gateway = "fd00::1"
      }
    }
  }

  mount_point {
    volume = "/mnt/NAS_Shared_Media"
    path   = "/mnt/NAS_Shared_Media"
  }
}
