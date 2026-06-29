locals {
  base_domain = "dominiksiejak.pl"

  ldap = {
    base_dn = "dc=dominiksiejak,dc=pl"
  }

  #───────────────────────────────────────────────────────────────────────────────
  # OAuth2 Applications
  #───────────────────────────────────────────────────────────────────────────────

  oauth2_applications = {
    portainer = {
      name          = "Portainer"
      launch_url    = "https://portainer.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/portainer.svg"
      redirect_uris = ["https://portainer.dominiksiejak.pl/"]
    }
    proxmox = {
      name          = "Proxmox"
      launch_url    = "https://proxmox.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/proxmox.svg"
      redirect_uris = ["https://proxmox.dominiksiejak.pl"]
    }
    netbox = {
      name          = "NetBox"
      launch_url    = "https://netbox.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/netbox.svg"
      redirect_uris = ["https://netbox.dominiksiejak.pl/oauth/complete/oidc/"]
    }
    vaultwarden = {
      name          = "Vaultwarden"
      launch_url    = "https://vaultwarden.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/vaultwarden.svg"
      redirect_uris = ["https://vaultwarden.dominiksiejak.pl/oidc-signin"]
    }
    n8n = {
      name          = "N8n"
      launch_url    = "https://n8n.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/n8n.svg"
      redirect_uris = ["https://n8n.dominiksiejak.pl/rest/oauth2-credential/callback"]
    }
    jellyfin = {
      name          = "Jellyfin"
      launch_url    = "https://jellyfin.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/jellyfin.svg"
      redirect_uris = ["https://jellyfin.dominiksiejak.pl/sso/OID/redirect/authentik"]
    }
    seerr = {
      name          = "Seerr"
      launch_url    = "https://seerr.dominiksiejak.pl/sso/OID/start/authentik"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/jellyseerr.svg"
      redirect_uris = ["http://seerr.dominiksiejak.pl/login?provider=authentik&callback=true"]
    }
    homeassistant = {
      name       = "Home Assistant"
      launch_url = "https://hass.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/home-assistant.svg"
      redirect_uris = [
        "https://hass.dominiksiejak.pl/auth/openid/callback",
      ]
    }
    synology = {
      name       = "Synology DSM"
      launch_url = "https://nas.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/synology-dsm.svg"
      redirect_uris = [
        "https://nas.dominiksiejak.pl",
        "http://192.168.89.240:5000",
        "https://192.168.89.240:5001",
      ]
    }
    vault = {
      name       = "Vault"
      launch_url = "https://vault.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/vault.svg"
      redirect_uris = [
        "https://vault.dominiksiejak.pl/ui/vault/auth/oidc/oidc/callback",
        "https://vault.dominiksiejak.pl/oidc/callback",
        "http://localhost:8250/oidc/callback",
      ]
    }
    gitea = {
      name       = "Gitea"
      launch_url = "https://git.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/gitea.svg"
      # Gitea callback path segment must match the authentication source *name* in Gitea (here: authentik).
      redirect_uris = ["https://git.dominiksiejak.pl/user/oauth2/authentik/callback"]
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
      launch_url    = "https://grafana.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/grafana.svg"
      redirect_uris = ["https://grafana.dominiksiejak.pl/login/generic_oauth"]
      mapping       = <<-EOF
        if request.user.ak_groups.filter(name="admins").exists():
            return {"role": "Admin"}
        elif request.user.ak_groups.filter(name="users").exists():
            return {"role": "Editor"}
        return {"role": "Viewer"}
      EOF
    }
  }

  #───────────────────────────────────────────────────────────────────────────────
  # Proxy Applications
  #───────────────────────────────────────────────────────────────────────────────

  proxy_applications = {
    victoriametrics = {
      name            = "VictoriaMetrics"
      external_host   = "https://metrics.dominiksiejak.pl"
      internal_host   = "http://monitoring:8428"
      launch_url      = "https://metrics.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/victoriametrics.svg"
      skip_path_regex = ""
    }
    qbittorrent = {
      name            = "qBittorrent"
      external_host   = "https://qbittorrent.dominiksiejak.pl"
      internal_host   = "http://qbittorrent:8080"
      launch_url      = "https://qbittorrent.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/qbittorrent.svg"
      skip_path_regex = ""
    }
    dozzle = {
      name            = "Dozzle"
      external_host   = "https://dozzle.dominiksiejak.pl"
      internal_host   = "http://dozzle:8080"
      launch_url      = "https://dozzle.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/dozzle.svg"
      skip_path_regex = ""
    }
    radarr = {
      name            = "Radarr"
      external_host   = "https://radarr.dominiksiejak.pl"
      internal_host   = "http://radarr:7878"
      launch_url      = "https://radarr.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/radarr.svg"
      skip_path_regex = "^/api/.*"
    }
    sonarr = {
      name            = "Sonarr"
      external_host   = "https://sonarr.dominiksiejak.pl"
      internal_host   = "http://sonarr:8989"
      launch_url      = "https://sonarr.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/sonarr.svg"
      skip_path_regex = "^/api/.*"
    }
    calibre = {
      name            = "Calibre"
      external_host   = "https://calibre.dominiksiejak.pl"
      internal_host   = "http://calibre:8080"
      launch_url      = "https://calibre.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/calibre.svg"
      skip_path_regex = ""
    }
    sabnzbd = {
      name            = "SABnzbd"
      external_host   = "https://sabnzbd.dominiksiejak.pl"
      internal_host   = "http://sabnzbd:8085"
      launch_url      = "https://sabnzbd.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/sabnzbd.svg"
      skip_path_regex = ""
    }
    traefik = {
      name            = "Traefik"
      external_host   = "https://traefik.dominiksiejak.pl"
      internal_host   = "http://traefik:8080"
      launch_url      = "https://traefik.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/traefik.svg"
      skip_path_regex = ""
    }
    zigbee2mqtt-wifi = {
      name            = "Zigbee2MQTT (WiFi)"
      external_host   = "https://zigbee2mqtt-wifi.dominiksiejak.pl"
      internal_host   = "http://zigbee2mqtt-wifi:8080"
      launch_url      = "https://zigbee2mqtt-wifi.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/zigbee2mqtt.svg"
      skip_path_regex = ""
    }
    zigbee2mqtt-usb = {
      name            = "Zigbee2MQTT (USB)"
      external_host   = "https://zigbee2mqtt-usb.dominiksiejak.pl"
      internal_host   = "http://zigbee2mqtt-usb:8080"
      launch_url      = "https://zigbee2mqtt-usb.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/zigbee2mqtt.svg"
      skip_path_regex = ""
    }
    watchyourlan = {
      name            = "WatchYourLAN"
      external_host   = "https://watchyourlan.dominiksiejak.pl"
      internal_host   = "http://watchyourlan:8840"
      launch_url      = "https://watchyourlan.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/watchyourlan.png"
      skip_path_regex = ""
    }
    hass-timemachine = {
      name            = "HASS Time Machine"
      external_host   = "https://hass-timemachine.dominiksiejak.pl"
      internal_host   = "http://hass-timemachine:3000"
      launch_url      = "https://hass-timemachine.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/home-assistant.svg"
      skip_path_regex = ""
    }
    adminer = {
      name            = "Adminer"
      external_host   = "https://adminer.dominiksiejak.pl"
      internal_host   = "http://adminer:8080"
      launch_url      = "https://adminer.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/adminer.svg"
      skip_path_regex = ""
    }
  }

  #───────────────────────────────────────────────────────────────────────────────
  # Dashboard Applications
  #───────────────────────────────────────────────────────────────────────────────

  dashboard_applications = {
    gatus = {
      name       = "Gatus"
      launch_url = "https://status.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/gatus.svg"
    }
    prowlarr = {
      name       = "Prowlarr"
      launch_url = "https://prowlarr.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/prowlarr.svg"
    }
    esphome = {
      name       = "ESPHome"
      launch_url = "https://esphome.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/esphome.svg"
    }
  }

  #───────────────────────────────────────────────────────────────────────────────
  # Access Control
  #───────────────────────────────────────────────────────────────────────────────

  user_accessible_apps = toset([
    "calibre",
    "dozzle",
    "gatus",
    "gitea",
    "grafana",
    "jellyfin",
    "seerr",
    "n8n",
    "netbox",
    "qbittorrent",
    "radarr",
    "sonarr",
    "synology",
    "vaultwarden",
    "victoriametrics",
    "watchyourlan",
    "zigbee2mqtt-wifi",
    "zigbee2mqtt-usb",
  ])
}
