# Non-secret defaults. Secrets: local.secret (ephemeral from OpenBao).
# Residual (regular resource attrs): local.vault via data.vault_kv_secret_v2.
locals {
  cfg = {
    proxmox_endpoint          = "https://proxmox.dominiksiejak.pl:8006"
    proxmox_insecure          = true
    proxmox_openid_client_id  = "proxmox"
    proxmox_openid_issuer_url = "https://auth.dominiksiejak.pl/application/o/proxmox/"
    proxmox_ssh_username      = "root"
  }
}
