terraform {
  required_version = ">= 1.11.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.77.0"
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
