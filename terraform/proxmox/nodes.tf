data "proxmox_virtual_environment_nodes" "all_nodes" {}

resource "proxmox_virtual_environment_dns" "default" {
  for_each  = toset(data.proxmox_virtual_environment_nodes.all_nodes.names)
  node_name = each.value

  domain = "home"
  servers = [
    "192.168.89.251", # LXC: adguard
    "fd00::53",       # LXC: adguard
    "1.1.1.1",
  ]
}


resource "proxmox_virtual_environment_time" "first_node_time" {
  for_each  = toset(data.proxmox_virtual_environment_nodes.all_nodes.names)
  node_name = each.value

  time_zone = "UTC"
}
