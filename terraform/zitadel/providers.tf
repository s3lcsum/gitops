terraform {
  required_version = ">= 1.11.0"

  required_providers {
    zitadel = {
      source  = "zitadel/zitadel"
      version = "2.2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.0"
    }
  }

  cloud {
    workspaces {
      name = "gitops-zitadel"
    }
  }
}

provider "zitadel" {
  domain   = var.zitadel_domain
  port     = var.zitadel_port
  insecure = var.zitadel_insecure

  # Use jwt_file for presigned JWT token
  jwt_file = "${path.root}/admin.pat"
}
