resource "wireguard_asymmetric_key" "server" {
}

resource "routeros_interface_wireguard" "default" {
  name        = "wg0"
  listen_port = var.wireguard_listen_port
}

resource "wireguard_asymmetric_key" "peers" {
  for_each = var.wireguard_peers
}

resource "routeros_interface_wireguard_peer" "peers" {
  for_each = var.wireguard_peers

  interface = routeros_interface_wireguard.default.name

  name            = each.key
  allowed_address = [each.value]
  private_key     = wireguard_asymmetric_key.peers[each.key].private_key
  public_key      = wireguard_asymmetric_key.peers[each.key].public_key
}

data "wireguard_config_document" "peers" {
  for_each = var.wireguard_peers

  addresses   = [each.value]
  private_key = wireguard_asymmetric_key.peers[each.key].private_key

  peer {
    public_key = wireguard_asymmetric_key.server.public_key
    endpoint   = "${var.wireguard_endpoint}:${var.wireguard_listen_port}"
    allowed_ips = [
      "192.168.89.0/24",
      "192.168.200.0/24"
    ]
    persistent_keepalive = 25
  }
}
