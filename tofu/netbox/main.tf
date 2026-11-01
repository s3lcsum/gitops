# NetBox objects driven by YAML under catalog/.
#   catalog/infrastructure/ — sites, locations, manufacturers, device_types, device_roles,
#                             cluster_types, clusters, platforms
#   catalog/inventory/      — devices, virtual_machines_*.yaml
#   catalog/networks/       — prefixes, ip_addresses (overlay; LAN IPs on devices)

# VM role tag for virtual machine device roles
resource "netbox_tag" "vm_role" {
  name = "vm_role"
  slug = "vm_role"
  tags = ["infrastructure"]
}

resource "netbox_tag" "site_tags" {
  for_each = local.sites

  name = each.value.slug
  slug = each.value.slug

  tags = [
    each.value.slug,
    "infrastructure"
  ]
}

resource "netbox_tag" "role_tags" {
  for_each = local.device_roles

  name = each.value.slug
  slug = each.value.slug

  tags = [
    each.value.slug,
    "infrastructure"
  ]
}

resource "netbox_tag" "location_tags" {
  for_each = local.locations

  name = each.value.slug
  slug = each.value.slug

  tags = [
    each.value.site,
    "location"
  ]
}

resource "netbox_manufacturer" "manufacturers" {
  for_each = local.manufacturers

  name = each.value.name
  slug = each.value.slug
}

resource "netbox_device_type" "device_types" {
  for_each = local.device_types

  model           = each.value.model
  slug            = each.value.slug
  manufacturer_id = netbox_manufacturer.manufacturers[each.value.manufacturer].id
  u_height        = each.value.u_height
}

resource "netbox_device_role" "device_roles" {
  for_each = local.device_roles

  name        = each.value.name
  slug        = each.value.slug
  description = each.value.description
  color_hex   = each.value.color_hex
  vm_role     = each.value.vm_role

  tags = each.value.vm_role ? [netbox_tag.vm_role.name] : ["infrastructure"]
}

resource "netbox_site" "sites" {
  for_each = local.sites

  name        = each.value.name
  slug        = each.value.slug
  description = each.value.description
  status      = "active"

  tags = local.common_tags
}

resource "netbox_location" "locations" {
  for_each = local.locations

  name        = each.value.name
  slug        = each.value.slug
  description = each.value.description
  site_id     = netbox_site.sites[each.value.site].id

  tags = local.common_tags
}

resource "netbox_prefix" "prefixes" {
  for_each = local.prefixes

  prefix      = each.value.prefix
  site_id     = netbox_site.sites[each.value.site].id
  description = each.value.description
  is_pool     = each.value.is_pool
  status      = each.value.status

  tags = concat(local.common_tags, [netbox_tag.site_tags[each.value.site].name])
}

resource "netbox_device" "devices" {
  for_each = local.devices

  name           = each.value.name
  device_type_id = netbox_device_type.device_types[each.value.device_type].id
  role_id        = netbox_device_role.device_roles[each.value.role].id
  site_id        = netbox_site.sites[each.value.site].id
  location_id    = try(each.value.location, null) != null ? netbox_location.locations[each.value.location].id : null
  cluster_id     = try(each.value.cluster, null) != null ? netbox_cluster.clusters[each.value.cluster].id : null
  status         = try(each.value.status, "active")

  tags = concat(
    local.common_tags,
    [netbox_tag.site_tags[each.value.site].name],
    try(each.value.location, null) != null ? [netbox_tag.location_tags[each.value.location].name] : []
  )

  description = try(each.value.description, "${each.value.name} - ${netbox_device_type.device_types[each.value.device_type].model}")
}

resource "netbox_ip_address" "static" {
  for_each = local.ip_addresses

  ip_address  = each.value.address
  status      = each.value.status
  description = each.value.description

  tags = concat(local.common_tags, [netbox_tag.site_tags[each.value.site].name])
}

resource "netbox_ip_address" "devices" {
  for_each = {
    for key, device in local.devices : key => device
    if try(device.ip_address, null) != null
  }

  ip_address  = each.value.ip_address
  status      = "active"
  description = try(each.value.description, "Static IP for ${each.key}")

  tags = concat(
    local.common_tags,
    [netbox_tag.site_tags[each.value.site].name]
  )
}
