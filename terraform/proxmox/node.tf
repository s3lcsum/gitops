resource "proxmox_virtual_environment_dns" "lake" {
  node_name = local.node_name
  domain    = "home"
  servers = [
    "192.168.89.253",
    "192.168.89.1",
  ]
}

resource "proxmox_virtual_environment_cluster_options" "options" {
  keyboard   = "pl"
  mac_prefix = "BC:24:11"
}
