# NetBox catalog: YAML under catalog/<area>/*.yaml (basename = map key inside file).
# Edit YAML only; main.tf resources read these locals.

locals {
  catalog_root = "${path.module}/catalog"

  catalog_infrastructure = {
    for f in fileset("${local.catalog_root}/infrastructure", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${local.catalog_root}/infrastructure/${f}"))
  }

  catalog_inventory = {
    for f in fileset("${local.catalog_root}/inventory", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${local.catalog_root}/inventory/${f}"))
  }

  catalog_networks = {
    for f in fileset("${local.catalog_root}/networks", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${local.catalog_root}/networks/${f}"))
  }

  sites         = try(local.catalog_infrastructure["sites"].sites, {})
  locations     = try(local.catalog_infrastructure["locations"].locations, {})
  manufacturers = try(local.catalog_infrastructure["manufacturers"].manufacturers, {})
  device_types  = try(local.catalog_infrastructure["device_types"].device_types, {})
  device_roles  = try(local.catalog_infrastructure["device_roles"].device_roles, {})
  cluster_types = try(local.catalog_infrastructure["cluster_types"].cluster_types, {})
  clusters      = try(local.catalog_infrastructure["clusters"].clusters, {})
  platforms     = try(local.catalog_infrastructure["platforms"].platforms, {})

  devices = try(local.catalog_inventory["devices"].devices, {})
  virtual_machines = merge(
    try(local.catalog_inventory["virtual_machines_platform"].virtual_machines, {}),
    try(local.catalog_inventory["virtual_machines_workloads"].virtual_machines, {}),
  )
  prefixes     = try(local.catalog_networks["prefixes"].prefixes, {})
  ip_addresses = try(local.catalog_networks["ip_addresses"].ip_addresses, {})

  common_tags = ["homelab", "infrastructure"]
}
