# Dual-run QEMU control plane beside CT 101 (.252). USB Zigbee and
# /mnt/nas-media stay on the LXC until cutover — see
# docs/superpowers/specs/2026-10-12-k8s-lxc-to-vm-design.md.

resource "proxmox_virtual_environment_download_file" "debian_13_cloud" {
  content_type = "import"
  datastore_id = "local"
  node_name    = local.node_name
  url          = local.debian_cloud_image_url
  file_name    = local.debian_cloud_image_file
}

resource "proxmox_virtual_environment_vm" "k8s" {
  node_name = local.node_name
  vm_id     = 102
  name      = "k8s"

  started         = true
  on_boot         = true
  stop_on_destroy = true

  agent {
    enabled = true
  }

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 16384
  }

  operating_system {
    type = "l26"
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_virtual_environment_download_file.debian_13_cloud.id
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    size         = 96
  }

  network_device {
    bridge   = "vmbr0"
    firewall = false
    model    = "virtio"
  }

  initialization {
    datastore_id = "local-lvm"

    dns {
      domain  = "dominiksiejak.pl"
      servers = ["192.168.89.252", "192.168.89.1"]
    }

    ip_config {
      ipv4 {
        address = "192.168.89.253/24"
        gateway = "192.168.89.1"
      }
    }

    user_account {
      username = "debian"
      keys     = var.k8s_vm_ssh_public_keys
    }
  }

  serial_device {
    device = "socket"
  }

  lifecycle {
    ignore_changes = [
      disk[0].import_from,
    ]
  }
}
