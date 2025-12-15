terraform {
  required_version = ">= 1.11.0"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "0.71.0"
    }
  }

  cloud {
    workspaces {
      name = "gitops-terraform-cloud"
    }
  }
}

provider "tfe" {
}
