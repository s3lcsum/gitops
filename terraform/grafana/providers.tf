terraform {
  required_version = ">= 1.11.5"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "4.45.1"
    }
  }

  backend "gcs" {
    bucket = "dominiksiejak-gitops-tfstate"
    prefix = "gitops-grafana"
  }
}

provider "grafana" {
  url  = var.grafana_url
  auth = "${var.grafana_admin_user}:${var.grafana_admin_password}"
}
