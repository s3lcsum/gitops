locals {
  # Base domain for all applications
  base_domain = "lake.dominiksiejak.pl"

  # LDAP configuration
  ldap = {
    base_dn = "dc=dominiksiejak,dc=pl"
  }

  # Google OAuth from terraform-gcp
  # google_oauth = data.tfe_outputs.gcp.values.google_oauth_authentik

  # Groups to create
  groups = {
    admins = {
      name         = "admins"
      is_superuser = true
    }
    users = {
      name         = "users"
      is_superuser = false
    }
    ldap_search = {
      name         = "ldap-search"
      is_superuser = false
    }
    jellyfin_users = {
      name         = "jellyfin-users"
      is_superuser = false
    }
    jellyfin_admins = {
      name         = "jellyfin-admins"
      is_superuser = false
    }
  }

  # OAuth2/OIDC Applications (native SSO)
  oauth2_applications = {
    portainer = {
      name          = "Portainer"
      slug          = "portainer"
      base_url      = "https://portainer.lake.dominiksiejak.pl"
      redirect_uris = ["https://portainer.lake.dominiksiejak.pl/"]
      launch_url    = "https://portainer.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/portainer.svg"
    }
    proxmox = {
      name          = "Proxmox"
      slug          = "proxmox"
      base_url      = "https://proxmox.lake.dominiksiejak.pl"
      redirect_uris = ["https://proxmox.lake.dominiksiejak.pl"]
      launch_url    = "https://proxmox.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/proxmox.svg"
    }
    netbox = {
      name          = "NetBox"
      slug          = "netbox"
      base_url      = "https://netbox.lake.dominiksiejak.pl"
      redirect_uris = ["https://netbox.lake.dominiksiejak.pl/oauth/complete/oidc/"]
      launch_url    = "https://netbox.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/netbox.svg"
    }
    vaultwarden = {
      name          = "Vaultwarden"
      slug          = "vaultwarden"
      base_url      = "https://vaultwarden.lake.dominiksiejak.pl"
      redirect_uris = ["https://vaultwarden.lake.dominiksiejak.pl/oidc-signin"]
      launch_url    = "https://vaultwarden.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/vaultwarden.svg"
    }
    synology = {
      name          = "Synology DSM"
      slug          = "synology"
      base_url      = "https://synology.lake.dominiksiejak.pl"
      redirect_uris = ["https://synology.lake.dominiksiejak.pl"]
      launch_url    = "https://synology.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/synology-dsm.svg"
    }
    n8n = {
      name          = "N8n"
      slug          = "n8n"
      base_url      = "https://n8n.lake.dominiksiejak.pl"
      redirect_uris = ["https://n8n.lake.dominiksiejak.pl/rest/oauth2-credential/callback"]
      launch_url    = "https://n8n.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/n8n.svg"
    }
    warrtracker = {
      name          = "Warrtracker"
      slug          = "warrtracker"
      base_url      = "https://warrtracker.lake.dominiksiejak.pl"
      redirect_uris = ["https://warrtracker.lake.dominiksiejak.pl/"]
      launch_url    = "https://warrtracker.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/warrtracker.svg"
    }
    jellyfin = {
      name          = "Jellyfin"
      slug          = "jellyfin"
      base_url      = "https://jellyfin.lake.dominiksiejak.pl"
      redirect_uris = ["https://jellyfin.lake.dominiksiejak.pl/sso/OID/r"]
      launch_url    = "https://jellyfin.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/jellyfin.svg"
    }
    homeassistant = {
      name          = "Home Assistant"
      slug          = "homeassistant"
      base_url      = "https://hass.lake.dominiksiejak.pl"
      redirect_uris = ["https://hass.lake.dominiksiejak.pl/auth/openid/callback"]
      launch_url    = "https://hass.lake.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/home-assistant.svg"
    }
  }

  # Proxy Provider Applications (forward auth via Traefik)
  proxy_applications = {
    uptime_kuma = {
      name          = "Uptime Kuma"
      slug          = "uptime-kuma"
      external_host = "https://uptime-kuma.lake.dominiksiejak.pl"
      internal_host = "http://uptime-kuma:3001"
      launch_url    = "https://uptime-kuma.lake.dominiksiejak.pl/dashboard"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/uptime-kuma.svg"
      # Unauthenticated paths for public status pages
      skip_path_regex = "^/status/.*|^/assets/.*|^/api/push/.*|^/api/badge/.*|^/api/status-page/heartbeat/.*|^/icon.svg|^/upload/.*"
    }
    sonarr = {
      name            = "Sonarr"
      slug            = "sonarr"
      external_host   = "https://sonarr.lake.dominiksiejak.pl"
      internal_host   = "http://sonarr:8989"
      launch_url      = "https://sonarr.lake.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/sonarr.svg"
      skip_path_regex = "^/api/.*"
    }
    radarr = {
      name            = "Radarr"
      slug            = "radarr"
      external_host   = "https://radarr.lake.dominiksiejak.pl"
      internal_host   = "http://radarr:7878"
      launch_url      = "https://radarr.lake.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/radarr.svg"
      skip_path_regex = "^/api/.*"
    }
    cups = {
      name            = "CUPS"
      slug            = "cups"
      external_host   = "https://cups.lake.dominiksiejak.pl"
      internal_host   = "http://cups:631"
      launch_url      = "https://cups.lake.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/cups.svg"
      skip_path_regex = ""
    }
    dozzle = {
      name            = "Dozzle"
      slug            = "dozzle"
      external_host   = "https://dozzle.lake.dominiksiejak.pl"
      internal_host   = "http://dozzle:8080"
      launch_url      = "https://dozzle.lake.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/dozzle.svg"
      skip_path_regex = ""
    }
    watchyourlan = {
      name            = "WatchYourLAN"
      slug            = "watchyourlan"
      external_host   = "https://watchyourlan.lake.dominiksiejak.pl"
      internal_host   = "http://watchyourlan:8840"
      launch_url      = "https://watchyourlan.lake.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/watchyourlan.png"
      skip_path_regex = ""
    }
  }

  # Dashboard Only Applications (no authentication, just app launcher)
  dashboard_applications = {
    adguard = {
      name       = "AdGuard Home"
      slug       = "adguard"
      launch_url = "https://adguard.lake.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/adguard-home.svg"
    }
    calibre = {
      name       = "Calibre"
      slug       = "calibre"
      launch_url = "https://calibre.lake.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/calibre-web.svg"
    }
    qbittorrent = {
      name       = "qBittorrent"
      slug       = "qbittorrent"
      launch_url = "https://qbittorrent.lake.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/qbittorrent.svg"
    }
    upsnap = {
      name       = "Upsnap"
      slug       = "upsnap"
      launch_url = "https://upsnap.lake.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/upsnap.svg"
    }
    jellyseerr = {
      name       = "Jellyseerr"
      slug       = "jellyseerr"
      launch_url = "https://jellyseerr.lake.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/jellyseerr.svg"
    }
  }
}
