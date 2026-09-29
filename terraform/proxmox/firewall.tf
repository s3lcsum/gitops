resource "proxmox_virtual_environment_cluster_firewall" "cluster" {
  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
}

resource "proxmox_virtual_environment_firewall_rules" "cluster" {
  rule {
    type    = "in"
    action  = "ACCEPT"
    source  = "100.64.0.0/10"
    proto   = "tcp"
    dport   = "22,8006,3128"
    comment = "mgmt: Tailscale"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    source  = "192.168.89.0/24"
    proto   = "tcp"
    dport   = "22,8006,3128"
    comment = "mgmt: LAN"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    source  = "192.168.200.0/24"
    proto   = "tcp"
    dport   = "22,8006,3128"
    comment = "mgmt: LAN"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    source  = "127.0.0.1"
    proto   = "tcp"
    dport   = "22"
    comment = "ngrok agent forwards to local sshd"
  }
}
