resource "routeros_system_identity" "main" {
  name = local.router_identity
}

resource "routeros_bridge" "default" {
  name           = "bridge"
  comment        = "defconf"
  protocol_mode  = "rstp"
  vlan_filtering = false
  fast_forward   = true
  dhcp_snooping  = false
  igmp_snooping  = false
  mvrp           = false
}

resource "routeros_ip_pool" "default" {
  name   = "defconf"
  ranges = local.lan.pool_ranges
}

resource "routeros_dhcp_server_network" "default" {
  address        = local.lan.cidr
  boot_file_name = local.lan.boot_file
  comment        = "defconf"
  dns_server     = local.lan.dns_servers
  domain         = local.lan.domain
  gateway        = local.lan.gateway
  netmask        = 24
}

resource "routeros_dns" "main" {
  allow_remote_requests       = true
  cache_max_ttl               = "1w"
  cache_size                  = 2048
  max_concurrent_queries      = 100
  max_concurrent_tcp_sessions = 20
  max_udp_packet_size         = 4096
  query_server_timeout        = "2s"
  query_total_timeout         = "10s"
  servers                     = local.dns.servers
  verify_doh_cert             = false
  vrf                         = "main"
}

resource "routeros_system_ntp_client" "test" {
  enabled = true
  mode    = "unicast"
  servers = local.ntp.servers
  vrf     = "main"
}
