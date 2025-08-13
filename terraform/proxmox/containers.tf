moved {
  from = proxmox_virtual_environment_container.adguard
  to   = module.lxc_adguard.proxmox_virtual_environment_container.this
}

module "lxc_adguard" {
  source = "./modules/lxc_container"

  node_name = data.proxmox_virtual_environment_nodes.all_nodes.names[0]
  hostname  = "adguard"

  disk              = { datastore_id = "local-lvm", size = 2 }
  memory            = { dedicated = 512, swap = 512 }
  network_interface = { bridge = "vmbr0", name = "eth0" }
  os_type           = "debian"
  template_file_id  = ""
  ip_config = {
    ipv4 = { address = "192.168.89.251/24", gateway = "192.168.89.1" }
    ipv6 = { address = "fd89:1::53/64", gateway = "fd89:1::1" }
  }

  dns = {
    domain  = "wally.dominiksiejak.pl"
    servers = ["127.0.0.1"]
  }
}


moved {
  from = proxmox_virtual_environment_container.portainer
  to   = module.lxc_portainer.proxmox_virtual_environment_container.this
}

module "lxc_portainer" {
  source = "./modules/lxc_container"

  node_name = data.proxmox_virtual_environment_nodes.all_nodes.names[0]
  hostname  = "portainer"

  disk              = { datastore_id = "local-lvm", size = 40 }
  memory            = { dedicated = 4096, swap = 2048 }
  network_interface = { bridge = "vmbr0", name = "eth0" }
  os_type           = "debian"
  template_file_id  = ""

  ip_config = {
    ipv4 = { address = "192.168.89.253/24", gateway = "192.168.89.1" }
    ipv6 = { address = "fd89:3::253/64", gateway = "fd89:3::1" }
  }

  dns = {
    domain  = "wally.dominiksiejak.pl"
    servers = ["192.168.89.251", "fd89:1::53"]
  }

  mount_points = [
    { volume = "/mnt/NAS_Shared_Media", path = "/mnt/NAS_Shared_Media" }
  ]
}

module "lxc_postgresql" {
  source = "./modules/lxc_container"

  node_name = data.proxmox_virtual_environment_nodes.all_nodes.names[0]
  hostname  = "postgresql"

  disk              = { datastore_id = "local-lvm", size = 20 }
  memory            = { dedicated = 2048, swap = 1024 }
  network_interface = { bridge = "vmbr0", name = "eth0" }
  os_type           = "debian"
  template_file_id  = ""

  ip_config = {
    ipv4 = { address = "192.168.89.252/24", gateway = "192.168.89.1" }
    ipv6 = { address = "fd89:1::252/64", gateway = "fd89:1::1" }
  }

  dns = {
    domain  = "wally.dominiksiejak.pl"
    servers = ["192.168.89.251", "fd89:1::53"]
  }
}

module "lxc_cloudflare_tunnel" {
  source = "./modules/lxc_container"

  node_name = data.proxmox_virtual_environment_nodes.all_nodes.names[0]
  hostname  = "cf-tunnel"

  disk              = { datastore_id = "local-lvm", size = 8 }
  memory            = { dedicated = 512, swap = 512 }
  network_interface = { bridge = "vmbr0", name = "eth0" }
  os_type           = "debian"
  template_file_id  = ""

  ip_config = {
    ipv4 = { address = "192.168.89.250/24", gateway = "192.168.89.1" }
    ipv6 = { address = "fd89:0::250/64", gateway = "fd89:0::1" }
  }

  dns = {
    domain  = "wally.dominiksiejak.pl"
    servers = ["192.168.89.251", "fd89:1::53"]
  }
}
