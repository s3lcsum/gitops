locals {
  authentik_oauth2_apps = {
    proxmox = {
      urls = [
        "https://proxmox.wally.dominiksiejak.pl/",
      ]
    }
    portainer = {
      urls = [
        "https://portainer.wally.dominiksiejak.pl/",
      ]
    }
    minio = {
      urls = [
        "https://minio.wally.dominiksiejak.pl/",
      ]
    }
  }
}
