terraform {
  required_version = ">= 1.11.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.114.0"
    }
  }

  backend "remote" {
    hostname     = "terrakube-api.dominiksiejak.pl"
    organization = "HomeLab"
    workspaces {
      name = "proxmox"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = var.proxmox_insecure

  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}
