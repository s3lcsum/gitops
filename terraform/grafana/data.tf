data "terraform_remote_state" "authentik" {
  backend = "gcs"
  config = {
    bucket = "dominiksiejak-gitops-tfstate"
    prefix = "gitops-authentik"
  }
}

data "grafana_oncall_user" "pager" {
  username = var.oncall_username
}
