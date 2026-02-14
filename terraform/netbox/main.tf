# Load all YAML data files
locals {
  # Load YAML data
  infrastructure = yamldecode(file("${path.module}/data/infrastructure.yaml"))
  inventory      = yamldecode(file("${path.module}/data/inventory.yaml"))
  networks       = yamldecode(file("${path.module}/data/networks.yaml"))

  # Create lookup maps for fast references
  sites         = local.infrastructure.sites
  locations     = local.infrastructure.locations
  manufacturers = local.infrastructure.manufacturers
  device_types  = local.infrastructure.device_types
  device_roles  = local.infrastructure.device_roles

  # Tags
  common_tags = ["homelab", "infrastructure"]
}

# VM role tag for virtual machine device roles
resource "netbox_tag" "vm_role" {
  name = "vm_role"
  slug = "vm_role"
  tags = ["infrastructure"]
}

# Create tags from sites
resource "netbox_tag" "site_tags" {
  for_each = local.sites

  name = each.value.slug
  slug = each.value.slug

  tags = [
    each.value.slug,
    "infrastructure"
  ]
}

# Create tags for device types
resource "netbox_tag" "role_tags" {
  for_each = local.device_roles

  name = each.value.slug
  slug = each.value.slug

  tags = [
    each.value.slug,
    "infrastructure"
  ]
}

# Create tags for datacenter locations
resource "netbox_tag" "location_tags" {
  for_each = local.locations

  name = each.value.slug
  slug = each.value.slug

  tags = [
    each.value.site,
    "location"
  ]
}

# Create manufacturers
resource "netbox_manufacturer" "manufacturers" {
  for_each = local.manufacturers

  name = each.value.name
  slug = each.value.slug
}

# Create device types
resource "netbox_device_type" "device_types" {
  for_each = local.device_types

  model           = each.value.model
  slug            = each.value.slug
  manufacturer_id = netbox_manufacturer.manufacturers[each.value.manufacturer].id
  u_height        = each.value.u_height
}

# Create device roles
resource "netbox_device_role" "device_roles" {
  for_each = local.device_roles

  name        = each.value.name
  slug        = each.value.slug
  description = each.value.description
  color_hex   = each.value.color_hex
  vm_role     = each.value.vm_role

  tags = each.value.vm_role ? [netbox_tag.vm_role.name] : ["infrastructure"]
}

# Create sites
resource "netbox_site" "sites" {
  for_each = local.sites

  name        = each.value.name
  slug        = each.value.slug
  description = each.value.description
  status      = "active"

  tags = local.common_tags
}

# Create locations
resource "netbox_location" "locations" {
  for_each = local.locations

  name        = each.value.name
  slug        = each.value.slug
  description = each.value.description
  site_id     = netbox_site.sites[each.value.site].id

  tags = local.common_tags
}

# Create network prefixes
resource "netbox_prefix" "prefixes" {
  for_each = local.networks.prefixes

  prefix      = each.value.prefix
  site_id     = netbox_site.sites[each.value.site].id
  description = each.value.description
  is_pool     = each.value.is_pool
  status      = each.value.status

  tags = concat(local.common_tags, [netbox_tag.site_tags[each.value.site].name])
}

# Create devices
resource "netbox_device" "devices" {
  for_each = local.inventory.devices

  name           = each.value.name
  device_type_id = netbox_device_type.device_types[each.value.device_type].id
  role_id        = netbox_device_role.device_roles[each.value.role].id
  site_id        = netbox_site.sites[each.value.site].id
  location_id    = contains(each.value, "location") ? netbox_location.locations[each.value.location].id : null
  status         = contains(each.value, "status") ? each.value.status : "active"

  tags = concat(
    local.common_tags,
    [netbox_tag.site_tags[each.value.site].name],
    contains(each.value.location, "location") ? [netbox_tag.location_tags[each.value.location].name] : []
  )

  description = contains(each.value, "description") ? each.value.description : "${each.value.name} - ${netbox_device_type.device_types[each.value.device_type].model}"
}

# Create IP addresses for devices
resource "netbox_ip_address" "ip_addresses" {
  for_each = {
    for key, device in local.inventory.devices : key => { ip = device.ip_address, name = key } if contains(device, "ip_address")
  }

  ip_address  = each.value.ip
  status      = "active"
  description = "Static IP for ${each.value.name}"

  tags = concat(
    local.common_tags,
    [netbox_tag.site_tags[local.inventory.devices[each.value.name].site].name]
  )
}
