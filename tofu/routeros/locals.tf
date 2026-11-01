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
    # DHCP option 15 — clients append this for short names (vibe → vibe.dominiksiejak.pl).
    # Prefer AdGuard (LAN rewrites); RouterOS as fallback. RouterOS recursive upstream is
    # set separately on routeros_dns.main (1.1.1.1 / 9.9.9.9).
    domain = "dominiksiejak.pl"
    servers = [
      "192.168.89.252",
      "192.168.89.1",
    ]
  }

  ntp = {
    servers = [
      "tempus1.gum.gov.pl",
      "tempus2.gum.gov.pl",
    ]
  }

  # Mikrus VPS on wg0. Firebird listens on the default port there.
  # Peer entry lives in gitignored defaults.auto.tfvars (micrus = this /32).
  micrus = {
    wireguard_ip  = "192.168.200.40"
    firebird_port = "3050"
  }
}
