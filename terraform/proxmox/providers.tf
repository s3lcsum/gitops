terraform {
  required_version = ">= 1.11.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.109.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.11.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.9.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.3.0"
    }
  }

  cloud {
    hostname     = "app.terraform.io"
    organization = "dominiksiejak"

    workspaces {
      name = "gitops-proxmox"
    }
  }
}

provider "proxmox" {
  endpoint  = var.virtual_environment_endpoint
  api_token = var.virtual_environment_api_token
  insecure  = local.virtual_environment_insecure
  ssh {
    agent    = local.virtual_environment_ssh_agent
    username = local.virtual_environment_username
  }
}

# Talos provider — used for machine config generation, apply, and bootstrap.
# Endpoint and node are passed per-resource from variables.
provider "talos" {}
