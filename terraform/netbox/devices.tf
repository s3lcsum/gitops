# Physical devices in the network

# DC-0 (Jarocin) - Routers
resource "netbox_device" "dc0_main_router" {
  name           = "Main Router"
  device_type_id = netbox_device_type.router_generic.id
  role_id        = netbox_device_role.router.id
  site_id        = netbox_site.dc0_jarocin.id
  location_id    = netbox_location.dc0_network_closet.id
  status         = "active"


  tags = [
    netbox_tag.dc0.name,
    netbox_tag.router.name
  ]
}

resource "netbox_device" "dc0_second_router" {
  name           = "Second Router"
  device_type_id = netbox_device_type.router_generic.id
  role_id        = netbox_device_role.router.id
  site_id        = netbox_site.dc0_jarocin.id
  location_id    = netbox_location.dc0_network_closet.id
  status         = "active"

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.router.name
  ]
}

# DC-0 (Jarocin) - Access Points
resource "netbox_device" "dc0_ap_0" {
  name           = "AP-0"
  device_type_id = netbox_device_type.access_point_generic.id
  role_id        = netbox_device_role.access_point.id
  site_id        = netbox_site.dc0_jarocin.id
  location_id    = netbox_location.dc0_network_closet.id
  status         = "active"

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.access_point.name
  ]
}

resource "netbox_device" "dc0_ap_1" {
  name           = "AP-1"
  device_type_id = netbox_device_type.access_point_generic.id
  role_id        = netbox_device_role.access_point.id
  site_id        = netbox_site.dc0_jarocin.id
  location_id    = netbox_location.dc0_network_closet.id
  status         = "active"

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.access_point.name
  ]
}

resource "netbox_device" "dc0_ap_2" {
  name           = "AP-2"
  device_type_id = netbox_device_type.access_point_generic.id
  role_id        = netbox_device_role.access_point.id
  site_id        = netbox_site.dc0_jarocin.id
  location_id    = netbox_location.dc0_network_closet.id
  status         = "active"

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.access_point.name
  ]
}

# DC-0 (Jarocin) - Printer
resource "netbox_device" "dc0_printer" {
  name           = "Sharp MX-4071"
  device_type_id = netbox_device_type.printer_generic.id
  role_id        = netbox_device_role.printer.id
  site_id        = netbox_site.dc0_jarocin.id
  location_id    = netbox_location.dc0_server_room.id
  status         = "active"

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.printer.name
  ]
}

# DC-0 (Jarocin) - IoT Device
resource "netbox_device" "dc0_zbbridge" {
  name           = "ZBBridge Pro"
  device_type_id = netbox_device_type.iot_generic.id
  role_id        = netbox_device_role.iot_device.id
  site_id        = netbox_site.dc0_jarocin.id
  location_id    = netbox_location.dc0_server_room.id
  status         = "active"

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.iot.name
  ]
}

# DC-0 (Jarocin) - Servers
resource "netbox_device" "dc0_rpi_1" {
  name           = "RPi-1"
  device_type_id = netbox_device_type.raspberry_pi.id
  role_id        = netbox_device_role.container_host.id
  site_id        = netbox_site.dc0_jarocin.id
  location_id    = netbox_location.dc0_server_room.id
  status         = "active"

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.lxc.name
  ]
}

resource "netbox_device" "dc0_home_assistant" {
  name           = "Home Assistant"
  device_type_id = netbox_device_type.server_generic.id
  role_id        = netbox_device_role.virtual_machine.id
  site_id        = netbox_site.dc0_jarocin.id
  location_id    = netbox_location.dc0_server_room.id
  status         = "active"

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.vm.name
  ]
}

resource "netbox_device" "dc0_portainer" {
  name           = "Portainer"
  device_type_id = netbox_device_type.server_generic.id
  role_id        = netbox_device_role.virtual_machine.id
  site_id        = netbox_site.dc0_jarocin.id
  location_id    = netbox_location.dc0_server_room.id
  status         = "active"

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.vm.name
  ]
}

resource "netbox_device" "dc0_lake_1" {
  name           = "Lake-1"
  device_type_id = netbox_device_type.server_generic.id
  role_id        = netbox_device_role.hypervisor.id
  site_id        = netbox_site.dc0_jarocin.id
  location_id    = netbox_location.dc0_server_room.id
  status         = "active"

  tags = [
    netbox_tag.dc0.name,
    netbox_tag.proxmox.name
  ]
}

# DC-1 (Wrocław) - Router
resource "netbox_device" "dc1_main_router" {
  name           = "Main Router"
  device_type_id = netbox_device_type.router_generic.id
  role_id        = netbox_device_role.router.id
  site_id        = netbox_site.dc1_wroclaw.id
  location_id    = netbox_location.dc1_server_room.id
  status         = "active"

  tags = [
    netbox_tag.dc1.name,
    netbox_tag.router.name
  ]
}

# DC-1 (Wrocław) - Servers
resource "netbox_device" "dc1_atom_1" {
  name           = "Atom-1"
  device_type_id = netbox_device_type.server_generic.id
  role_id        = netbox_device_role.hypervisor.id
  site_id        = netbox_site.dc1_wroclaw.id
  location_id    = netbox_location.dc1_server_room.id
  status         = "active"

  tags = [
    netbox_tag.dc1.name,
    netbox_tag.proxmox.name
  ]
}

resource "netbox_device" "dc1_portainer_2" {
  name           = "Portainer-2"
  device_type_id = netbox_device_type.server_generic.id
  role_id        = netbox_device_role.virtual_machine.id
  site_id        = netbox_site.dc1_wroclaw.id
  location_id    = netbox_location.dc1_server_room.id
  status         = "active"

  tags = [
    netbox_tag.dc1.name,
    netbox_tag.vm.name
  ]
}
