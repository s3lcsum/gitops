data "terraform_remote_state" "authentik" {
  backend = "remote"
  config = {
    hostname     = "terrakube-api.dominiksiejak.pl"
    organization = "HomeLab"
    workspaces = {
      name = "authentik"
    }
  }
}

data "grafana_oncall_user" "pager" {
  username = var.oncall_username
}
