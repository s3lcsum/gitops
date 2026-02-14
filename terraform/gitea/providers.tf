terraform {
  required_version = ">= 1.11.0"

  required_providers {
    gitea = {
      source  = "go-gitea/gitea"
      version = "0.6.0"
    }
  }

  cloud {
    hostname     = "app.terraform.io"
    organization = "dominiksiejak"

    workspaces {
      name = "gitops-gitea"
    }
  }
}

provider "gitea" {
  base_url = "https://git.lake.dominiksiejak.pl"
  token    = var.gitea_token
  username = var.gitea_username
  password = var.gitea_password
}
