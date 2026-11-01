terraform {
  required_version = ">= 1.11.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.119.0"
    }
  }
}

provider "proxmox" {
  endpoint  = local.cfg.proxmox_endpoint
  api_token = "${local.secret.proxmox_api_token_id}=${local.secret.proxmox_api_token_secret}"
  insecure  = local.cfg.proxmox_insecure

  ssh {
    agent    = true
    username = local.cfg.proxmox_ssh_username
  }
}
