terraform {
  required_version = ">= 1.11.0"

  required_providers {
    routeros = {
      source  = "terraform-routeros/routeros"
      version = "1.85.0"
    }
  }

  cloud {
    workspaces {
      name = "gitops-routeros"
    }
  }
}

provider "routeros" {
}
