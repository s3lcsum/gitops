locals {
  # Project configuration (non-sensitive)
  projects = {
    homelab = {
      name                     = "HomeLab"
      project_role_assertion   = false
      project_role_check       = false
      has_project_check        = false
      private_labeling_setting = "PRIVATE_LABELING_SETTING_UNSPECIFIED"
    }
  }

  # Common OIDC application defaults
  oidc_defaults = {
    project_key    = "homelab"
    response_types = ["OIDC_RESPONSE_TYPE_CODE"]
    grant_types    = ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE"]
    app_type       = "OIDC_APP_TYPE_WEB"
  }

  # OIDC applications configuration
  oidc_applications = {
    login_client = merge(local.oidc_defaults, {
      name                      = "Login Client"
      redirect_uris             = ["https://${var.zitadel_domain}/ui/v2/login/login/callback"]
      post_logout_redirect_uris = ["https://${var.zitadel_domain}/ui/v2/login/logout"]
    })
    portainer = merge(local.oidc_defaults, {
      name                      = "Portainer"
      redirect_uris             = ["https://portainer.lake.dominiksiejak.pl/"]
      access_token_type         = "OIDC_TOKEN_TYPE_JWT"
      grant_types               = ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE", "OIDC_GRANT_TYPE_REFRESH_TOKEN"]
      post_logout_redirect_uris = ["https://portainer.lake.dominiksiejak.pl/"]
    })
  }


}
