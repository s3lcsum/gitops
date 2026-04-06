# Talos on Proxmox — https://registry.terraform.io/modules/bbtechsys/talos/proxmox
# Uses Talos Image Factory metal qcow2 + qemu-guest-agent (schematic) so Proxmox can report
# node IPv4s to Terraform (no hardcoded apply targets).
module "talos_lake" {
  source  = "registry.terraform.io/bbtechsys/talos/proxmox"
  version = "0.1.6"

  proxmox_iso_datastore        = var.talos_import_datastore_id
  proxmox_image_datastore      = var.talos_datastore_id
  proxmox_network_bridge       = var.talos_bridge
  proxmox_control_vm_cores     = var.talos_control_vm_cores
  proxmox_control_vm_memory    = var.talos_control_vm_memory
  proxmox_control_vm_disk_size = var.talos_control_vm_disk_size
  proxmox_vm_type              = var.talos_proxmox_vm_cpu_type

  talos_cluster_name = local.talos_cluster_name
  talos_version      = local.talos_version_number
  talos_schematic_id = var.talos_schematic_id
  talos_arch         = "amd64"

  control_nodes = {
    for k in sort(keys(local.talos_nodes)) : "talos-${k}" => local.proxmox_node_name
  }
  worker_nodes = {}

  control_plane_mac_addresses = {
    for k, v in local.talos_nodes : "talos-${k}" => v.mac
  }

  control_machine_config_patches = concat(
    [file("${path.module}/talos-cluster-network.patch.yaml")],
    [yamlencode({
      machine = {
        network = {
          nameservers = var.talos_nameservers
          interfaces = [
            {
              interface = var.talos_physical_interface
              dhcp      = true
            }
          ]
        }
        sysctls = {
          "net.ipv6.conf.all.accept_ra"     = "2"
          "net.ipv6.conf.default.accept_ra" = "2"
        }
      }
    })],
    [yamlencode({
      cluster = {
        apiServer = {
          certSANs = local.talos_cp_cert_sans
        }
      }
    })],
    [<<-EOT
machine:
  install:
    disk: "/dev/vda"
EOT
    ]
  )
}
