terraform {
  required_version = ">= 1.11.0"

  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "1.26.0"
    }
  }

  cloud {
    hostname     = "app.terraform.io"
    organization = "dominiksiejak"

    workspaces {
      name = "gitops-postgres"
    }
  }
}

provider "postgresql" {
  host            = var.postgres_host
  port            = var.postgres_port
  database        = var.postgres_database
  username        = var.postgres_admin_username
  password        = var.postgres_admin_password
  sslmode         = var.postgres_sslmode
  connect_timeout = 15
}
