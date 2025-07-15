# Firewall Filter Rules

# Allow ICMP (ping)
resource "routeros_firewall_filter" "icmp" {
  chain    = "input"
  action   = "accept"
  protocol = "icmp"
  comment  = "Allow ICMP (ping)"
}

# Accept established, related, untracked connections
resource "routeros_ip_firewall_filter" "established_related" {
  chain            = "input"
  action           = "accept"
  connection_state = "established,related,untracked"
  comment          = "Accept established, related, untracked"
}

# Allow SSH from LAN
resource "routeros_firewall_filter" "ssh_lan" {
  chain             = "input"
  action            = "accept"
  protocol          = "tcp"
  dst_port          = "22"
  in_interface_list = routeros_interface_list.lan.name
  comment           = "Allow SSH from LAN"
}

# Allow HTTP/HTTPS management from LAN
resource "routeros_firewall_filter" "web_management_lan" {
  for_each = toset(["80", "443"])

  chain             = "input"
  action            = "accept"
  protocol          = "tcp"
  dst_port          = each.value
  in_interface_list = routeros_interface_list.lan.name
  comment           = "Allow HTTP/HTTPS management from LAN"
}

# Allow DNS from LAN
resource "routeros_firewall_filter" "dns_lan" {
  for_each = toset(["tcp", "udp"])

  chain             = "input"
  action            = "accept"
  protocol          = each.value
  dst_port          = "53"
  in_interface_list = routeros_interface_list.lan.name
  comment           = "Allow DNS from LAN"
}

# Allow DHCP from LAN
resource "routeros_firewall_filter" "dhcp_lan" {
  chain             = "input"
  action            = "accept"
  protocol          = "udp"
  dst_port          = "67"
  in_interface_list = routeros_interface_list.lan.name
  comment           = "Allow DHCP from LAN"
}

# Allow NTP from LAN
resource "routeros_firewall_filter" "ntp_lan" {
  chain             = "input"
  action            = "accept"
  protocol          = "udp"
  dst_port          = "123"
  in_interface_list = routeros_interface_list.lan.name
  comment           = "Allow NTP from LAN"
}

# Allow SNMP from specific hosts (for metrics collection)
resource "routeros_firewall_filter" "snmp_metrics" {
  chain       = "input"
  action      = "accept"
  protocol    = "udp"
  dst_port    = "161"
  src_address = "192.168.89.254,192.168.89.11" # wally and edge-1
  comment     = "Allow SNMP from metrics collectors"
}

# Allow Winbox from LAN
resource "routeros_firewall_filter" "winbox_lan" {
  chain             = "input"
  action            = "accept"
  protocol          = "tcp"
  dst_port          = "8291"
  in_interface_list = routeros_interface_list.lan.name
  comment           = "Allow Winbox from LAN"
}

# Drop invalid connections
resource "routeros_firewall_filter" "drop_invalid" {
  chain            = "input"
  action           = "drop"
  connection_state = "invalid"
  comment          = "Drop invalid connections"
}

# Rate limit SSH connections (simplified without address lists)
resource "routeros_firewall_filter" "ssh_rate_limit" {
  chain            = "input"
  action           = "drop"
  protocol         = "tcp"
  dst_port         = "22"
  connection_state = "new"
  src_address      = "!192.168.89.0/24"
  comment          = "Drop SSH from non-LAN"
}

# Drop all other input from WAN
resource "routeros_firewall_filter" "drop_wan_input" {
  chain             = "input"
  action            = "drop"
  in_interface_list = routeros_interface_list.wan.name
  comment           = "Drop all other input from WAN"
  log               = true
  log_prefix        = "WAN-INPUT-DROP: "
}

# Drop all other input not from LAN
resource "routeros_firewall_filter" "drop_non_lan" {
  chain             = "input"
  action            = "drop"
  in_interface_list = "!${routeros_interface_list.lan.name}"
  comment           = "Drop all not coming from LAN"
  log               = true
  log_prefix        = "NON-LAN-DROP: "
}

# Forward chain rules
# Accept established, related connections in forward
resource "routeros_firewall_filter" "forward_established_related" {
  chain            = "forward"
  action           = "accept"
  connection_state = "established,related"
  comment          = "Accept established, related in forward"
}

# Accept LAN to WAN forward
resource "routeros_firewall_filter" "forward_lan_to_wan" {
  chain              = "forward"
  action             = "accept"
  in_interface_list  = routeros_interface_list.lan.name
  out_interface_list = routeros_interface_list.wan.name
  comment            = "Accept LAN to WAN forward"
}

# Drop invalid forward connections
resource "routeros_firewall_filter" "forward_drop_invalid" {
  chain            = "forward"
  action           = "drop"
  connection_state = "invalid"
  comment          = "Drop invalid forward connections"
}

# Drop all other forward
resource "routeros_firewall_filter" "forward_drop_all" {
  chain      = "forward"
  action     = "drop"
  comment    = "Drop all other forward"
  log        = true
  log_prefix = "FORWARD-DROP: "
}

# NAT Rules
# Masquerade LAN to WAN
resource "routeros_firewall_nat" "masquerade" {
  chain              = "srcnat"
  action             = "masquerade"
  out_interface_list = routeros_interface_list.wan.name
  comment            = "Masquerade LAN to WAN"
}
