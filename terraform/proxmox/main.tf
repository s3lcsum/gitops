terraform {
  required_version = ">= 1.11.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.78.2"
    }
  }

  cloud {
    workspaces {
      name = "gitops-proxmox"
    }
  }
}

provider "proxmox" {
}
