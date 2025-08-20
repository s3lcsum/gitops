terraform {
  required_version = ">= 1.11.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.82.1"
    }
  }
  cloud {
    workspaces {
      name = "gitops-proxmox"
    }
  }
}

provider "proxmox" {
  # Skip TLS verification for self-signed certificates
  insecure = true
}

data "proxmox_virtual_environment_nodes" "all_nodes" {}
