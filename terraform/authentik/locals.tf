locals {
  base_domain = "dominiksiejak.pl"

  ldap = {
    base_dn = "dc=dominiksiejak,dc=pl"
  }

  #───────────────────────────────────────────────────────────────────────────────
  # OAuth2 Applications
  #───────────────────────────────────────────────────────────────────────────────

  oauth2_applications = {
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
    n8n = {
      name          = "N8n"
      launch_url    = "https://n8n.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/n8n.svg"
      redirect_uris = ["https://n8n.dominiksiejak.pl/rest/oauth2-credential/callback"]
    }
    openbao = {
      name       = "OpenBao"
      launch_url = "https://openbao.dominiksiejak.pl"
      icon_url   = "https://raw.githubusercontent.com/openbao/artwork/refs/heads/main/color/openbao-color.svg"
      redirect_uris = [
        "https://openbao.dominiksiejak.pl/ui/vault/auth/oidc/oidc/callback",
      ]
    }
    seerr = {
      name          = "Seerr"
      launch_url    = "https://seerr.dominiksiejak.pl/sso/OID/start/authentik"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/jellyseerr.svg"
      redirect_uris = ["https://seerr.dominiksiejak.pl/login?provider=authentik&callback=true"]
    }
    homeassistant = {
      name       = "Home Assistant"
      launch_url = "https://hass.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/home-assistant.svg"
      redirect_uris = [
        "https://hass.dominiksiejak.pl/auth/openid/callback",
      ]
    }
    wealthfolio = {
      name       = "Wealthfolio"
      launch_url = "https://wealthfolio.dominiksiejak.pl"
      icon_url   = "https://raw.githubusercontent.com/wealthfolio/wealthfolio/main/app-icon.png"
      redirect_uris = [
        "https://wealthfolio.dominiksiejak.pl/api/v1/auth/oidc/callback",
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
    # Public + PKCE: Grafana Cloud's token call comes from US and is blocked by
    # the Cloudflare country WAF. A public client does not send client_secret.
    grafana-cloud = {
      name          = "Grafana Cloud"
      launch_url    = var.grafana_cloud_url
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/grafana.svg"
      client_type   = "public"
      redirect_uris = ["${trimsuffix(var.grafana_cloud_url, "/")}/login/generic_oauth"]
      mapping       = <<-EOF
        if request.user.ak_groups.filter(name="admins").exists():
            return {"role": "Admin"}
        elif request.user.ak_groups.filter(name="users").exists():
            return {"role": "Editor"}
        return {"role": "Viewer"}
      EOF
    }
    # Calibre-Web Automated (calibre.dominiksiejak.pl) — native OIDC SSO via the
    # generic OAuth provider in CWA. Callback path is fixed by CWA.
    # CWA emits the redirect_uri with scheme http (Flask-Dance url_for ignores
    # X-Forwarded-Proto), so both http and https must be allowed; Traefik
    # 301-redirects the http callback to https before it reaches the app.
    calibre-web-automated = {
      name       = "Calibre-Web Automated"
      launch_url = "https://calibre.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/calibre.svg"
      redirect_uris = [
        "https://calibre.dominiksiejak.pl/login/generic/authorized",
        "http://calibre.dominiksiejak.pl/login/generic/authorized",
      ]
    }
    # Cloudflare Zero Trust Access — generic OIDC IdP.
    # Callback team name must match terraform/cloudflare tunnel_team_name.
    cloudflare = {
      name       = "Cloudflare"
      launch_url = "https://one.dash.cloudflare.com/"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/cloudflare.svg"
      redirect_uris = [
        "https://dominiksiejak.cloudflareaccess.com/cdn-cgi/access/callback",
      ]
    }
    # UI is https://argocd.dominiksiejak.pl (Cilium Gateway).
    # 8080/8085 stay for port-forward and `argocd login --sso`.
    argocd = {
      name       = "Argo CD"
      launch_url = "https://argocd.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/argo-cd.svg"
      redirect_uris = [
        "https://argocd.dominiksiejak.pl/auth/callback",
        "http://localhost:8080/auth/callback",
        "http://localhost:8085/auth/callback",
      ]
    }
    # Dex OIDC connector. Callback is the API host, not the UI.
    # Client id must match security.dexClientId (terrakube).
    terrakube = {
      name       = "Terrakube"
      launch_url = "https://terrakube.dominiksiejak.pl"
      icon_url   = "https://avatars.githubusercontent.com/u/80990539"
      redirect_uris = [
        "https://terrakube-api.dominiksiejak.pl/dex/callback",
      ]
    }
  }

  #───────────────────────────────────────────────────────────────────────────────
  # Proxy Applications
  #───────────────────────────────────────────────────────────────────────────────

  proxy_applications = {
    victoriametrics = {
      name            = "VictoriaMetrics"
      external_host   = "https://metrics.dominiksiejak.pl"
      internal_host   = "http://victoria-metrics.monitoring.svc:8428"
      launch_url      = "https://metrics.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/victoriametrics.svg"
      skip_path_regex = ""
    }
    # calibre.dominiksiejak.pl (CWA) is NOT forward-auth'd — CWA handles its own
    # auth: local users + native OIDC SSO via the "calibre-web-automated" app.
    # No proxy application here; only calibre-gui is Authentik-gated.
    calibre-gui = {
      name            = "Calibre GUI"
      external_host   = "https://calibre-gui.dominiksiejak.pl"
      internal_host   = "http://calibre.calibre.svc:8080"
      launch_url      = "https://calibre-gui.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/calibre.svg"
      skip_path_regex = ""
    }
    # Chart Service is disabled. IngressRoute uses api@internal. API entrypoint
    # is host :9080 (UniFi owns :8080). forward_single does not dial this.
    traefik = {
      name            = "Traefik"
      external_host   = "https://traefik.dominiksiejak.pl"
      internal_host   = "http://192.168.89.252:9080"
      launch_url      = "https://traefik.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/traefik.svg"
      skip_path_regex = ""
    }
    zigbee2mqtt-wifi = {
      name            = "Zigbee2MQTT (WiFi)"
      external_host   = "https://zigbee2mqtt-wifi.dominiksiejak.pl"
      internal_host   = "http://zigbee2mqtt-wifi.hass.svc:8080"
      launch_url      = "https://zigbee2mqtt-wifi.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/zigbee2mqtt.svg"
      skip_path_regex = ""
    }
    zigbee2mqtt-usb = {
      name            = "Zigbee2MQTT (USB)"
      external_host   = "https://zigbee2mqtt-usb.dominiksiejak.pl"
      internal_host   = "http://zigbee2mqtt-usb.hass.svc:8080"
      launch_url      = "https://zigbee2mqtt-usb.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/zigbee2mqtt.svg"
      skip_path_regex = ""
    }
    watchyourlan = {
      name            = "WatchYourLAN"
      external_host   = "https://lan.dominiksiejak.pl"
      internal_host   = "http://watchyourlan.watchyourlan.svc:8840"
      launch_url      = "https://lan.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/watchyourlan.png"
      skip_path_regex = ""
    }
    hass-timemachine = {
      name            = "HASS Time Machine"
      external_host   = "https://hass-timemachine.dominiksiejak.pl"
      internal_host   = "http://hass-timemachine.hass.svc:54000"
      launch_url      = "https://hass-timemachine.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/home-assistant.svg"
      skip_path_regex = ""
    }
    adguard = {
      name          = "AdGuard"
      external_host = "https://adguard.dominiksiejak.pl"
      internal_host = "http://adguard.adguard.svc:3000"
      launch_url    = "https://adguard.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/adguard-home.svg"
      # DoH only — /control is the admin API and must stay Authentik-gated.
      skip_path_regex = "^/dns-query.*"
    }
    zigbee-bridge = {
      name            = "Zigbee Bridge"
      external_host   = "https://zigbee-bridge.dominiksiejak.pl"
      internal_host   = "http://lan-zigbee-bridge.traefik.svc:80"
      launch_url      = "https://zigbee-bridge.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/zigbee2mqtt.svg"
      skip_path_regex = ""
    }
    # Headlamp UI (k8s Traefik IngressRoute + authentik middleware).
    # forward_single: outpost only auths; Traefik proxies to ClusterIP.
    # Admins only — the pod service account is cluster-admin.
    headlamp = {
      name            = "Headlamp"
      external_host   = "https://headlamp.dominiksiejak.pl"
      internal_host   = "http://headlamp.headlamp.svc:80"
      launch_url      = "https://headlamp.dominiksiejak.pl"
      icon_url        = "https://raw.githubusercontent.com/kubernetes-sigs/headlamp/v0.45.0/docs/headlamp_light.svg"
      skip_path_regex = ""
    }
    # Policy Reporter UI (k8s Traefik IngressRoute + authentik middleware).
    # forward_single: outpost only auths; Traefik proxies to ClusterIP.
    policy-reporter = {
      name            = "Policy Reporter"
      external_host   = "https://policy-reporter.dominiksiejak.pl"
      internal_host   = "http://policy-reporter-ui.policy-reporter.svc:8080"
      launch_url      = "https://policy-reporter.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/kyverno.svg"
      skip_path_regex = ""
    }
    # qBittorrent WebUI auth is off (subnet whitelist). Traefik forward-auth is the gate.
    # forward_single: outpost only auths; Traefik proxies to the gluetun pod.
    qbittorrent = {
      name            = "qBittorrent"
      external_host   = "https://qbittorrent.dominiksiejak.pl"
      internal_host   = "http://gluetun.mediabox.svc:8080"
      launch_url      = "https://qbittorrent.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/qbittorrent.png"
      skip_path_regex = ""
    }
  }

  #───────────────────────────────────────────────────────────────────────────────
  # Dashboard Applications
  #───────────────────────────────────────────────────────────────────────────────

  dashboard_applications = {
    # Tile only — UniFi has no free OIDC/LDAP; local admin still required after launch.
    # Traefik class = public (no Authentik forward-auth).
    unifi = {
      name       = "UniFi"
      launch_url = "https://unifi.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/unifi.svg"
    }
    # *arr classified native-oidc but no OIDC client is configured in this repo.
    # Tiles only — do not add oauth2 entries until each app has a real callback.
    bazarr = {
      name       = "Bazarr"
      launch_url = "https://bazarr.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/bazarr.svg"
    }
    jellyfin = {
      name       = "Jellyfin"
      launch_url = "https://jellyfin.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/jellyfin.svg"
    }
    profilarr = {
      name       = "Profilarr"
      launch_url = "https://profilarr.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/profilarr.svg"
    }
    prowlarr = {
      name       = "Prowlarr"
      launch_url = "https://prowlarr.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/prowlarr.svg"
    }
    radarr = {
      name       = "Radarr"
      launch_url = "https://radarr.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/radarr.svg"
    }
    sabnzbd = {
      name       = "SABnzbd"
      launch_url = "https://sabnzbd.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/sabnzbd.svg"
    }
    sonarr = {
      name       = "Sonarr"
      launch_url = "https://sonarr.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/sonarr.svg"
    }
  }

  #───────────────────────────────────────────────────────────────────────────────
  # Access Control
  #───────────────────────────────────────────────────────────────────────────────

  user_accessible_apps = toset([
    "gitea",
    "grafana",
    "grafana-cloud",
    "seerr",
    "n8n",
    "netbox",
    "synology",
    "victoriametrics",
    "watchyourlan",
    "zigbee2mqtt-wifi",
    "zigbee2mqtt-usb",
  ])
}
