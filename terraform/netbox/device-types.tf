# Device Types for various hardware

# Generic device types for network equipment
resource "netbox_device_type" "router_generic" {
  model           = "Generic Router"
  slug            = "router-generic"
  manufacturer_id = netbox_manufacturer.generic.id
  u_height        = 1

  tags = [netbox_tag.network.name]
}

resource "netbox_device_type" "access_point_generic" {
  model           = "Generic Access Point"
  slug            = "access-point-generic"
  manufacturer_id = netbox_manufacturer.tp_link.id
  u_height        = 1

  tags = [netbox_tag.network.name]
}

resource "netbox_device_type" "printer_generic" {
  model           = "Generic Printer"
  slug            = "printer-generic"
  manufacturer_id = netbox_manufacturer.sharp.id
  u_height        = 1

  tags = [netbox_tag.printer.name]
}

resource "netbox_device_type" "iot_generic" {
  model           = "Generic IoT Device"
  slug            = "iot-generic"
  manufacturer_id = netbox_manufacturer.generic.id
  u_height        = 1

  tags = [netbox_tag.iot.name]
}

resource "netbox_device_type" "raspberry_pi" {
  model           = "Raspberry Pi"
  slug            = "raspberry-pi"
  manufacturer_id = netbox_manufacturer.raspberry_pi.id
  u_height        = 1

  tags = [netbox_tag.infrastructure.name]
}

resource "netbox_device_type" "server_generic" {
  model           = "Generic Server"
  slug            = "server-generic"
  manufacturer_id = netbox_manufacturer.generic.id
  u_height        = 1

  tags = [netbox_tag.infrastructure.name]
}
