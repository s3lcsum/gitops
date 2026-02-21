terraform {
  required_version = ">= 1.11.0"

  required_providers {
    b2 = {
      source  = "Backblaze/b2"
      version = "0.12.1"
    }
  }

  cloud {
    hostname     = "app.terraform.io"
    organization = "dominiksiejak"

    workspaces {
      name = "gitops-backblaze"
    }
  }
}

provider "b2" {
  application_key_id = var.b2_application_key_id
  application_key    = var.b2_application_key
}
