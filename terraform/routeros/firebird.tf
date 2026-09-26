# Public TCP 3050 → Firebird on micrus over WireGuard.
# Client string: xero.dominiksiejak.pl:3050/BAZA_CPC.fdb
# The database name stays on the server; this only forwards the TCP session.
# WAN sources must be on address-list allowed-wan, same gate as :443.

resource "routeros_ip_firewall_nat" "firebird_wan" {
  comment           = "DSTNAT | WAN | Firebird | micrus"
  chain             = "dstnat"
  action            = "dst-nat"
  protocol          = "tcp"
  dst_port          = local.micrus.firebird_port
  in_interface_list = "WAN"
  src_address_list  = "allowed-wan"
  to_addresses      = local.micrus.wireguard_ip
  to_ports          = local.micrus.firebird_port
}

resource "routeros_ip_firewall_nat" "firebird_hairpin" {
  comment           = "DSTNAT | HAIRPIN | Firebird | micrus"
  chain             = "dstnat"
  action            = "dst-nat"
  protocol          = "tcp"
  dst_port          = local.micrus.firebird_port
  dst_address_list  = "wan-ip"
  in_interface_list = "LAN"
  to_addresses      = local.micrus.wireguard_ip
  to_ports          = local.micrus.firebird_port
}

resource "routeros_ip_firewall_filter" "firebird_forward" {
  comment     = "FORWARD | Firebird | micrus"
  chain       = "forward"
  action      = "accept"
  protocol    = "tcp"
  dst_address = local.micrus.wireguard_ip
  dst_port    = local.micrus.firebird_port
}
