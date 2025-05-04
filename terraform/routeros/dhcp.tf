resource "routeros_dhcp_server_network" "default" {
  comment = "defconf"

  address        = "192.168.89.0/24"
  gateway        = "192.168.89.1"
  dns_server     = ["192.168.89.251", "1.1.1.1"]
  domain         = "home"
  boot_file_name = "netboot.xyz.kpxe"
  netmask        = 24
}
