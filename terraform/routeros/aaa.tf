# RouterOS device admin login via Authentik RADIUS (auth.dominiksiejak.pl).
# The RADIUS secret is consumed from the gitops-authentik workspace output.
# The local admin account remains as fallback if Authentik/RADIUS is unreachable.

data "tfe_outputs" "authentik" {
  organization = "dominiksiejak"
  workspace    = "gitops-authentik"
}

resource "routeros_radius" "authentik" {
  address = "192.168.89.253"
  secret  = data.tfe_outputs.authentik.values.radius.secret
  service = ["login"]
}

resource "routeros_system_user_aaa" "main" {
  use_radius    = true
  default_group = "read"
}
