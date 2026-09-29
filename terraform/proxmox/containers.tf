# Privileged guest (no unprivileged: 1 in /etc/pve/lxc/101.conf).
# Raw lxc.* lines are not in the provider schema. They live only in the CT conf
# and must not be deleted:
#   101: apparmor unconfined, empty cap.drop, cgroup2 devices allow a,
#        mount.auto proc:rw sys:rw, bind /dev/kmsg and /dev/net/tun
# CT 100 (portainer, 192.168.89.253) is gone. Do not recreate it.

resource "proxmox_virtual_environment_container" "k8s" {
  node_name = local.node_name
  vm_id     = 101

  unprivileged  = false
  started       = true
  start_on_boot = true

  cpu {
    architecture = "amd64"
    cores        = 4
  }

  memory {
    dedicated = 16384
    swap      = 0
  }

  features {
    nesting = true
    keyctl  = true
    fuse    = true
  }

  initialization {
    hostname = "k8s"

    dns {
      domain  = "home"
      servers = ["192.168.89.253", "192.168.89.1"]
    }

    ip_config {
      ipv4 {
        address = "192.168.89.252/24"
        gateway = "192.168.89.1"
      }
    }
  }

  network_interface {
    name        = "eth0"
    bridge      = "vmbr0"
    firewall    = false
    mac_address = "BC:24:11:BD:83:07"
  }

  device_passthrough {
    path = "/dev/ttyUSB0"
    mode = "0660"
  }

  disk {
    datastore_id = "local-lvm"
    size         = 96
  }

  mount_point {
    volume = "/mnt/nas-media"
    path   = "/mnt/nas-media"
  }

  operating_system {
    template_file_id = local.debian_template
    type             = "debian"
  }

  lifecycle {
    ignore_changes = [
      operating_system[0].template_file_id,
    ]
  }
}
