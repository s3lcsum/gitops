resource "netbox_cluster_type" "cluster_types" {
  for_each = local.cluster_types

  name = each.value.name
  slug = try(each.value.slug, null)

  tags = local.common_tags
}

resource "netbox_cluster" "clusters" {
  for_each = local.clusters

  name            = each.value.name
  cluster_type_id = netbox_cluster_type.cluster_types[each.value.cluster_type].id
  site_id         = netbox_site.sites[each.value.site].id
  description     = try(each.value.description, null)

  tags = concat(local.common_tags, [netbox_tag.site_tags[each.value.site].name])
}

resource "netbox_platform" "platforms" {
  for_each = local.platforms

  name = each.value.name
  slug = try(each.value.slug, null)

  manufacturer_id = try(each.value.manufacturer, null) != null ? netbox_manufacturer.manufacturers[each.value.manufacturer].id : null

  tags = local.common_tags
}

resource "netbox_virtual_machine" "virtual_machines" {
  for_each = local.virtual_machines

  name        = each.value.name
  cluster_id  = netbox_cluster.clusters[each.value.cluster].id
  site_id     = netbox_site.sites[each.value.site].id
  role_id     = netbox_device_role.device_roles[each.value.role].id
  platform_id = try(each.value.platform, null) != null ? netbox_platform.platforms[each.value.platform].id : null
  status      = try(each.value.status, "active")
  description = try(each.value.description, null)

  vcpus     = try(each.value.vcpus, null)
  memory_mb = try(each.value.memory_mb, null)

  tags = concat(
    local.common_tags,
    [netbox_tag.site_tags[each.value.site].name],
    try(each.value.namespace, null) != null ? ["ns:${each.value.namespace}"] : [],
  )
}
