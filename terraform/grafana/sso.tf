# Authentik Generic OAuth for Grafana Cloud.
# Apply terraform/authentik first so remote-state applications.grafana-cloud exists.

resource "grafana_sso_settings" "authentik" {
  provider_name = "generic_oauth"

  oauth2_settings {
    enabled               = true
    name                  = "Authentik"
    client_id             = data.terraform_remote_state.authentik.outputs.applications["grafana-cloud"].client_id
    client_secret         = ""
    auth_style            = "InParams"
    auth_url              = data.terraform_remote_state.authentik.outputs.applications["grafana-cloud"].authorization_uri
    token_url             = data.terraform_remote_state.authentik.outputs.applications["grafana-cloud"].access_token_uri
    api_url               = "https://auth.dominiksiejak.pl/application/o/userinfo/"
    scopes                = "openid profile email grafana-cloud"
    allow_sign_up         = true
    auto_login            = false
    use_pkce              = true
    use_refresh_token     = true
    role_attribute_path   = "role"
    role_attribute_strict = false
    signout_redirect_url  = data.terraform_remote_state.authentik.outputs.applications["grafana-cloud"].logout_uri
  }
}
