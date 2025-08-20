locals {
  authentik_oauth2_apps = {
    proxmox = {
      urls = [
        "https://proxmox.lake.dominiksiejak.pl/",
      ]
    }
    portainer = {
      urls = [
        "https://portainer.lake.dominiksiejak.pl/",
      ]
    }
  }
}
