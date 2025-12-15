# Manufacturers for devices

resource "netbox_manufacturer" "generic" {
  name = "Generic"
  slug = "generic"
}

resource "netbox_manufacturer" "tp_link" {
  name = "TP-Link"
  slug = "tp-link"
}

resource "netbox_manufacturer" "sharp" {
  name = "Sharp"
  slug = "sharp"
}

resource "netbox_manufacturer" "raspberry_pi" {
  name = "Raspberry Pi Foundation"
  slug = "raspberry-pi"
}
