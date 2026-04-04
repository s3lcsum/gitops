# -----------------------------------------------------------------------------
# Image Factory — HTTP-based schematic ID (content-addressable)
# -----------------------------------------------------------------------------

data "http" "schematic_id" {
  url    = "${local.talos_factory_url}/schematics"
  method = "POST"

  request_headers = {
    Content-Type = "application/yaml"
  }

  request_body = local.talos_schematic
}

# -----------------------------------------------------------------------------
# Image download — one per distinct host node (deduped across nodes on same host)
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_download_file" "talos_iso" {
  for_each = { for k, v in local.talos_nodes : "${v.host_node}_${local.image_id}" => v... }

  # ISO storage can decompress gz. Use `disk.file_id` to attach raw image as a block device (not IDE CD-ROM).
  content_type            = "iso"
  datastore_id            = local.proxmox_storage
  node_name               = each.value[0].host_node
  url                     = "${local.talos_factory_url}/image/${local.schematic_id}/${local.talos_image_version}/${local.talos_platform}-${local.talos_arch}.raw.gz"
  file_name               = "talos-${substr(local.schematic_id, 0, 8)}-${local.talos_image_version}-${local.talos_platform}-${local.talos_arch}.img"
  decompression_algorithm = "gz"
}

# -----------------------------------------------------------------------------
# Talos machine configuration — per node
# -----------------------------------------------------------------------------

data "talos_machine_configuration" "this" {
  for_each = local.talos_nodes

  cluster_name     = local.talos_cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = each.value.machine_type
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  kubernetes_version = local.talos_kubernetes_version

  config_patches = [
    yamlencode({
      machine = {
        install = { disk = "/dev/sda" }
        network = {
          hostname = each.key
          interfaces = [{
            interface = "eth0"
            addresses = ["${each.value.ip}/24"]
            routes    = [{ network = "0.0.0.0/0", gateway = local.vm_gateway }]
          }]
        }
      }
      cluster = merge(
        {
          network = {
            podSubnets     = [local.talos_pod_subnet]
            serviceSubnets = [local.talos_service_subnet]
          }
        },
        each.value.machine_type == "controlplane" ? {
          extraManifests = [local.argocd_manifest_url]
        } : {}
      )
    })
  ]
}

# -----------------------------------------------------------------------------
# Talos client configuration
# -----------------------------------------------------------------------------

data "talos_client_configuration" "this" {
  cluster_name         = local.talos_cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for k, v in local.talos_controlplane_nodes : v.ip]
  nodes                = [for k, v in local.talos_nodes : v.ip]
}
