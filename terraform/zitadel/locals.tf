locals {
  # Project configuration (non-sensitive)
  projects = {
    homelab = {
      name = "HomeLab"
    }
  }

  # OIDC applications configuration
  oidc_applications = {
    login_client = {
      name                      = "Login Client"
      redirect_uris             = ["https://${var.zitadel_domain}/ui/v2/login/login/callback"]
      post_logout_redirect_uris = ["https://${var.zitadel_domain}/ui/v2/login/logout"]
    }
    portainer = {
      name                      = "Portainer"
      redirect_uris             = ["https://portainer.lake.dominiksiejak.pl/"]
      post_logout_redirect_uris = ["https://portainer.lake.dominiksiejak.pl/"]
    }
    proxmox = {
      name                      = "Proxmox"
      redirect_uris             = ["https://proxmox.lake.dominiksiejak.pl/"]
      post_logout_redirect_uris = ["https://proxmox.lake.dominiksiejak.pl/"]
    }
  }
}
