locals {
  base_domain = "lake.dominiksiejak.pl"

  ldap = {
    base_dn = "dc=dominiksiejak,dc=pl"
  }

  #───────────────────────────────────────────────────────────────────────────────
  # OAuth2 Applications
  #───────────────────────────────────────────────────────────────────────────────

  oauth2_applications = {
    portainer = {
      name          = "Portainer"
      launch_url    = "https://portainer.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/portainer.svg"
      redirect_uris = ["https://portainer.lake.dominiksiejak.pl/"]
    }
    proxmox = {
      name          = "Proxmox"
      launch_url    = "https://proxmox.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/proxmox.svg"
      redirect_uris = ["https://proxmox.lake.dominiksiejak.pl"]
    }
    netbox = {
      name          = "NetBox"
      launch_url    = "https://netbox.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/netbox.svg"
      redirect_uris = ["https://netbox.lake.dominiksiejak.pl/oauth/complete/oidc/"]
    }
    vaultwarden = {
      name          = "Vaultwarden"
      launch_url    = "https://vaultwarden.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/vaultwarden.svg"
      redirect_uris = ["https://vaultwarden.lake.dominiksiejak.pl/oidc-signin"]
    }
    n8n = {
      name          = "N8n"
      launch_url    = "https://n8n.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/n8n.svg"
      redirect_uris = ["https://n8n.lake.dominiksiejak.pl/rest/oauth2-credential/callback"]
    }
    jellyfin = {
      name          = "Jellyfin"
      launch_url    = "https://jellyfin.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/jellyfin.svg"
      redirect_uris = ["https://jellyfin.lake.dominiksiejak.pl/sso/OID/redirect/authentik"]
    }
    warracker = {
      name          = "Warracker"
      launch_url    = "https://warracker.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/warracker.png"
      redirect_uris = ["http://warracker.lake.dominiksiejak.pl/api/oidc/callback"]
      mapping       = <<-EOF
        if request.user.ak_groups.filter(name="admins").exists():
            return {"group": "admin"}
        return {"group": "user"}
      EOF
    }
    seerr = {
      name          = "Seerr"
      launch_url    = "https://seerr.lake.dominiksiejak.pl/sso/OID/start/authentik"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/jellyseerr.svg"
      redirect_uris = ["http://seerr.lake.dominiksiejak.pl/login?provider=authentik&callback=true"]
    }
    homeassistant = {
      name          = "Home Assistant"
      launch_url    = "https://hass.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/home-assistant.svg"
      redirect_uris = ["https://hass.lake.dominiksiejak.pl/auth/openid/callback"]
    }
    synology = {
      name       = "Synology DSM"
      launch_url = "https://nas.lake.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/synology-dsm.svg"
      redirect_uris = [
        "https://nas.lake.dominiksiejak.pl",
        "https://nas.hello.dominiksiejak.pl",
        "http://192.168.89.240:5000",
        "https://192.168.89.240:5001",
      ]
    }
    vault = {
      name       = "Vault"
      launch_url = "https://vault.lake.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/vault.svg"
      redirect_uris = [
        "https://vault.lake.dominiksiejak.pl/ui/vault/auth/oidc/oidc/callback",
        "https://vault.lake.dominiksiejak.pl/oidc/callback",
        "http://localhost:8250/oidc/callback",
      ]
    }
    gitea = {
      name          = "Gitea"
      launch_url    = "https://git.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/gitea.svg"
      redirect_uris = ["https://git.lake.dominiksiejak.pl/user/oauth2/authentik/callback"]
      mapping       = <<-EOF
        if request.user.ak_groups.filter(name="admins").exists():
            return {"gitea": "admin"}
        elif request.user.ak_groups.filter(name="users").exists():
            return {"gitea": "user"}
        return {"gitea": "public"}
      EOF
    }
    grafana = {
      name          = "Grafana"
      launch_url    = "https://grafana.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/grafana.svg"
      redirect_uris = ["https://grafana.lake.dominiksiejak.pl/login/generic_oauth"]
      mapping       = <<-EOF
        if request.user.ak_groups.filter(name="admins").exists():
            return {"role": "Admin"}
        elif request.user.ak_groups.filter(name="users").exists():
            return {"role": "Editor"}
        return {"role": "Viewer"}
      EOF
    }
    homarr = {
      name       = "Homarr"
      launch_url = "https://homarr.lake.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/homarr.svg"
      redirect_uris = [
        "https://homarr.lake.dominiksiejak.pl/api/auth/callback/oidc",
        "https://homarr.hello.dominiksiejak.pl/api/auth/callback/oidc",
        "http://localhost:7575/api/auth/callback/oidc",
      ]
    }
  }

  #───────────────────────────────────────────────────────────────────────────────
  # Proxy Applications
  #───────────────────────────────────────────────────────────────────────────────

  proxy_applications = {
    victoriametrics = {
      name            = "VictoriaMetrics"
      external_host   = "https://metrics.lake.dominiksiejak.pl"
      internal_host   = "http://monitoring:8428"
      launch_url      = "https://metrics.lake.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/victoriametrics.svg"
      skip_path_regex = ""
    }
    qbittorrent = {
      name            = "qBittorrent"
      external_host   = "https://qbittorrent.lake.dominiksiejak.pl"
      internal_host   = "http://qbittorrent:8080"
      launch_url      = "https://qbittorrent.lake.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/qbittorrent.svg"
      skip_path_regex = ""
    }
    dozzle = {
      name            = "Dozzle"
      external_host   = "https://dozzle.lake.dominiksiejak.pl"
      internal_host   = "http://dozzle:8080"
      launch_url      = "https://dozzle.lake.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/dozzle.svg"
      skip_path_regex = ""
    }
    radarr = {
      name            = "Radarr"
      external_host   = "https://radarr.lake.dominiksiejak.pl"
      internal_host   = "http://radarr:7878"
      launch_url      = "https://radarr.lake.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/radarr.svg"
      skip_path_regex = "^/api/.*"
    }
    sonarr = {
      name            = "Sonarr"
      external_host   = "https://sonarr.lake.dominiksiejak.pl"
      internal_host   = "http://sonarr:8989"
      launch_url      = "https://sonarr.lake.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/sonarr.svg"
      skip_path_regex = "^/api/.*"
    }
    watchyourlan = {
      name            = "WatchYourLAN"
      external_host   = "https://watchyourlan.lake.dominiksiejak.pl"
      internal_host   = "http://watchyourlan:8840"
      launch_url      = "https://watchyourlan.lake.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/watchyourlan.png"
      skip_path_regex = ""
    }
    firefly = {
      name            = "Firefly III"
      external_host   = "https://money.lake.dominiksiejak.pl"
      internal_host   = "http://firefly:8080"
      launch_url      = "https://money.lake.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/firefly-iii.svg"
      skip_path_regex = ""
    }
    calibre = {
      name            = "Calibre"
      external_host   = "https://calibre.lake.dominiksiejak.pl"
      internal_host   = "http://calibre:8080"
      launch_url      = "https://calibre.lake.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/calibre.svg"
      skip_path_regex = ""
    }
    beszel = {
      name            = "Beszel"
      external_host   = "https://beszel.lake.dominiksiejak.pl"
      internal_host   = "http://beszel:8080"
      launch_url      = "https://beszel.lake.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/beszel.svg"
      skip_path_regex = ""
    }
    sabnzbd = {
      name            = "SABnzbd"
      external_host   = "https://sabnzbd.lake.dominiksiejak.pl"
      internal_host   = "http://sabnzbd:8080"
      launch_url      = "https://sabnzbd.lake.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/sabnzbd.svg"
      skip_path_regex = ""
    }
    traefik = {
      name            = "Traefik"
      external_host   = "https://traefik.lake.dominiksiejak.pl"
      internal_host   = "http://traefik:8080"
      launch_url      = "https://traefik.lake.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/traefik.svg"
      skip_path_regex = ""
    }
  }

  #───────────────────────────────────────────────────────────────────────────────
  # Dashboard Applications
  #───────────────────────────────────────────────────────────────────────────────

  dashboard_applications = {
    adguard = {
      name       = "AdGuard Home"
      launch_url = "https://adguard.lake.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/adguard-home.svg"
    }
    gatus = {
      name       = "Gatus"
      launch_url = "https://status.lake.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/gatus.svg"
    }
    upsnap = {
      name       = "Upsnap"
      launch_url = "https://upsnap.lake.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/upsnap.svg"
    }
    bazarr = {
      name       = "Bazarr"
      launch_url = "https://bazarr.lake.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/bazarr.svg"
    }
    prowlarr = {
      name       = "Prowlarr"
      launch_url = "https://prowlarr.lake.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/prowlarr.svg"
    }
  }

  #───────────────────────────────────────────────────────────────────────────────
  # Access Control
  #───────────────────────────────────────────────────────────────────────────────

  user_accessible_apps = toset([
    "beszel",
    "calibre",
    "cups",
    "dozzle",
    "firefly",
    "gatus",
    "gitea",
    "grafana",
    "homarr",
    "jellyfin",
    "jellyseerr",
    "n8n",
    "netbox",
    "qbittorrent",
    "radarr",
    "sonarr",
    "synology",
    "upsnap",
    "vaultwarden",
    "victoriametrics",
    "warracker",
    "watchyourlan",
  ])
}
