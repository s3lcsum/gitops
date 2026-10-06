terraform {
  required_version = ">= 1.11.5"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "4.46.0"
    }
  }

  backend "remote" {
    hostname     = "terrakube-api.dominiksiejak.pl"
    organization = "HomeLab"
    workspaces {
      name = "grafana"
    }
  }
}

provider "grafana" {
  url  = var.grafana_cloud_url
  auth = var.grafana_cloud_auth

  # Provider default OnCall host is us-central-0. This stack is eu-west-0.
  oncall_url          = var.oncall_url
  oncall_access_token = var.oncall_access_token
}
