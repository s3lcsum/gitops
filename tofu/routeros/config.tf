# Non-secret defaults. Secrets: local.secret (ephemeral from OpenBao).
# OpenBao KV values must be strings only (int/map in secret/routeros breaks
# vault_kv_secret_v2). wireguard_* stays here — feeds for_each on resources.
locals {
  cfg = {
    wireguard_endpoint    = "vpn.dominiksiejak.pl"
    wireguard_listen_port = "51820"
    wireguard_peers = {
      "atom-1"          = "192.168.200.10/32"
      "dsiejak-ipad"    = "192.168.200.23/32"
      "dsiejak-iphone"  = "192.168.200.21/32"
      "dsiejak-macbook" = "192.168.200.20/32"
      "dsiejak-xgimi"   = "192.168.200.24/32"
      "github-actions"  = "192.168.200.254/32"
      "jsiejak-iphone"  = "192.168.200.31/32"
      "jsiejak-macbook" = "192.168.200.32/32"
      "micrus"          = "192.168.200.40/32"
    }
  }
}
