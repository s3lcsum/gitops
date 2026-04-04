terraform {
  required_version = ">= 1.11.5"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "0.76.1"
    }
  }

  cloud {
    hostname     = "app.terraform.io"
    organization = "dominiksiejak"

    workspaces {
      name = "gitops-terraform-cloud"
    }
  }
}

provider "tfe" {
}
