terraform {
  required_version = ">= 1.11.5"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "4.53.0"
    }
  }
}

provider "grafana" {
  url  = local.cfg.grafana_cloud_url
  auth = local.secret.grafana_cloud_auth

  # Provider default OnCall host is us-central-0. This stack is eu-west-0.
  oncall_url          = local.cfg.oncall_url
  oncall_access_token = local.secret.oncall_access_token
}
