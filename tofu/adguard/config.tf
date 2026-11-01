# Non-secret defaults. Secrets: local.secret (ephemeral from OpenBao).
locals {
  cfg = {
    adguard_host     = "192.168.89.252:3000"
    adguard_username = "dsiejak"
  }
}
