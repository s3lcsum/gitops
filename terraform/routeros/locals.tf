locals {
  router_identity = "MikroTik-MainRouter"

  lan = {
    cidr        = "192.168.89.0/24"
    gateway     = "192.168.89.1"
    pool_ranges = ["192.168.89.100-192.168.89.199"]
    domain      = local.dns.domain
    dns_servers = local.dns.servers
    boot_file   = "netboot.xyz.kpxe"
  }

  dns = {
    domain = "home"
    servers = [
      "1.1.1.1",
      "9.9.9.9",
    ]
  }

  ntp = {
    servers = [
      "tempus1.gum.gov.pl",
      "tempus2.gum.gov.pl",
    ]
  }
}
