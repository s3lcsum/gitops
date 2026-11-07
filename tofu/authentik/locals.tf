locals {
  base_domain = "dominiksiejak.pl"

  #───────────────────────────────────────────────────────────────────────────────
  # OAuth2 Applications
  #───────────────────────────────────────────────────────────────────────────────

  oauth2_applications = {
    proxmox = {
      name          = "Proxmox"
      launch_url    = "https://proxmox.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/proxmox.svg"
      redirect_uris = ["https://proxmox.dominiksiejak.pl"]
    }
    netbox = {
      name          = "NetBox"
      launch_url    = "https://netbox.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/netbox.svg"
      redirect_uris = ["https://netbox.dominiksiejak.pl/oauth/complete/oidc/"]
    }
    n8n = {
      name          = "N8n"
      launch_url    = "https://n8n.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/n8n.svg"
      redirect_uris = ["https://n8n.dominiksiejak.pl/rest/oauth2-credential/callback"]
    }
    openbao = {
      name       = "OpenBao"
      launch_url = "https://bao.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/openbao.svg"
      redirect_uris = [
        "https://bao.dominiksiejak.pl/ui/vault/auth/oidc/oidc/callback",
      ]
    }
    # aussierk/jellyfin-plugin-oidc (OIDC + RBAC). Two things this plugin needs
    # from the provider, both set below in applications.tf:
    #   - claims in the ID token (it reads the role claim from there first)
    #   - a stable `sub` (accounts are keyed on it, not on the username)
    #
    # Provider ID in the plugin config MUST be `authentik` to match the
    # redirect path segment. Role Claim Path = `groups`, supplied by the default
    # `profile` scope, so Role Mapping names in the plugin are the Authentik
    # group names it already has: `admins` and `users`.
    jellyfin = {
      name       = "Jellyfin"
      launch_url = "https://jellyfin.dominiksiejak.pl/sso/OIDC/Start/authentik"
      icon_url   = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/jellyfin.svg"
      redirect_uris = [
        # aussierk/jellyfin-plugin-oidc — path fixed by plugin ({providerId}=authentik)
        "https://jellyfin.dominiksiejak.pl/sso/OIDC/Callback/authentik",
      ]
      # Stable subject. The guide says "based on the user's username", but that
      # makes `sub` change on a rename and orphans the Jellyfin account; the
      # plugin's identity map is deliberately keyed on `sub` for this reason.
      sub_mode = "user_uuid"
      # OIDC Back-Channel Logout 1.0 endpoint the plugin exposes. Authentik
      # POSTs a signed logout_token here so an Authentik logout ends the
      # Jellyfin session too.
      logout_uri = "https://jellyfin.dominiksiejak.pl/sso/OIDC/BackchannelLogout/authentik"
    }
    seerr = {
      name       = "Seerr"
      launch_url = "https://seerr.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/jellyseerr.svg"
      redirect_uris = [
        "https://seerr.dominiksiejak.pl/login",
        "https://seerr.dominiksiejak.pl/profile/settings/linked-accounts",
      ]
    }
    # Servarr native OIDC (Radarr v7 / Sonarr v5 develop). Callback path is fixed
    # by ASP.NET Core. Set OidcAuthority to applications.<slug>.issuer_uri after
    # apply; remove Traefik forward-auth on the IngressRoute once config.xml uses Oidc.
    radarr = {
      name       = "Radarr"
      launch_url = "https://radarr.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/radarr.svg"
      redirect_uris = [
        "https://radarr.dominiksiejak.pl/signin-oidc",
      ]
      sub_mode = "user_uuid"
      # Servarr matches OidcUserIdentifier to the OIDC `sub` claim, not email.
    }
    sonarr = {
      name       = "Sonarr"
      launch_url = "https://sonarr.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/sonarr.svg"
      redirect_uris = [
        "https://sonarr.dominiksiejak.pl/signin-oidc",
      ]
      sub_mode = "user_uuid"
      # Servarr matches OidcUserIdentifier to the OIDC `sub` claim, not email.
    }
    homeassistant = {
      name       = "Home Assistant"
      launch_url = "https://hass.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/home-assistant.svg"
      redirect_uris = [
        "https://hass.dominiksiejak.pl/auth/openid/callback",
      ]
    }
    wealthfolio = {
      name       = "Wealthfolio"
      launch_url = "https://wealthfolio.dominiksiejak.pl"
      # No wealthfolio asset on dashboardicons.com
      icon_url = "https://raw.githubusercontent.com/wealthfolio/wealthfolio/main/app-icon.png"
      redirect_uris = [
        "https://wealthfolio.dominiksiejak.pl/api/v1/auth/oidc/callback",
      ]
    }
    sure = {
      name       = "Sure"
      launch_url = "https://sure.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/sure.svg"
      redirect_uris = [
        "https://sure.dominiksiejak.pl/auth/openid_connect/callback",
      ]
    }
    synology = {
      name       = "Synology DSM"
      launch_url = "https://nas.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/synology-dsm.svg"
      redirect_uris = [
        "https://nas.dominiksiejak.pl",
        "http://192.168.89.240:5000",
        "https://192.168.89.240:5001",
      ]
    }
    # Public + PKCE: Grafana Cloud's token call comes from US and is blocked by
    # the Cloudflare country WAF. A public client does not send client_secret.
    grafana-cloud = {
      name          = "Grafana Cloud"
      launch_url    = local.cfg.grafana_cloud_url
      icon_url      = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/grafana.svg"
      client_type   = "public"
      redirect_uris = ["${trimsuffix(local.cfg.grafana_cloud_url, "/")}/login/generic_oauth"]
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
      icon_url   = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/calibre.svg"
      redirect_uris = [
        "https://calibre.dominiksiejak.pl/login/generic/authorized",
        "http://calibre.dominiksiejak.pl/login/generic/authorized",
      ]
    }
    # Shelfmark native OIDC. Callback path is fixed by the app.
    # groups scope (applications.tf) maps Authentik group "admins" to Shelfmark admin.
    shelfmark = {
      name       = "Shelfmark"
      launch_url = "https://shelfmark.dominiksiejak.pl"
      icon_url   = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/lazylibrarian.svg"
      redirect_uris = [
        "https://shelfmark.dominiksiejak.pl/api/auth/oidc/callback",
      ]
    }
    # Cloudflare Zero Trust Access — generic OIDC IdP.
    # Callback team name must match terraform/cloudflare tunnel_team_name.
    cloudflare = {
      name       = "Cloudflare"
      launch_url = "https://one.dash.cloudflare.com/"
      icon_url   = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/cloudflare.svg"
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
      icon_url        = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/victoriametrics.svg"
      skip_path_regex = ""
    }
    # calibre.dominiksiejak.pl (CWA) and shelfmark.dominiksiejak.pl use native
    # OIDC. No forward-auth proxy for either.
    # Chart Service is disabled. IngressRoute uses api@internal. API entrypoint
    # is host :9080 (UniFi owns :8080). forward_single does not dial this.
    traefik = {
      name            = "Traefik"
      external_host   = "https://traefik.dominiksiejak.pl"
      internal_host   = "http://192.168.89.252:9080"
      launch_url      = "https://traefik.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/traefik.svg"
      skip_path_regex = ""
    }
    zigbee2mqtt-wifi = {
      name            = "Zigbee2MQTT (WiFi)"
      external_host   = "https://zigbee2mqtt-wifi.dominiksiejak.pl"
      internal_host   = "http://zigbee2mqtt-wifi.hass.svc:8080"
      launch_url      = "https://zigbee2mqtt-wifi.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/zigbee2mqtt.svg"
      skip_path_regex = ""
    }
    zigbee2mqtt-usb = {
      name            = "Zigbee2MQTT (USB)"
      external_host   = "https://zigbee2mqtt-usb.dominiksiejak.pl"
      internal_host   = "http://zigbee2mqtt-usb.hass.svc:8080"
      launch_url      = "https://zigbee2mqtt-usb.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/zigbee2mqtt.svg"
      skip_path_regex = ""
    }
    watchyourlan = {
      name            = "WatchYourLAN"
      external_host   = "https://lan.dominiksiejak.pl"
      internal_host   = "http://watchyourlan.watchyourlan.svc:8840"
      launch_url      = "https://lan.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/watchyourlan.png"
      skip_path_regex = ""
    }
    hass-timemachine = {
      name            = "HASS Time Machine"
      external_host   = "https://hass-timemachine.dominiksiejak.pl"
      internal_host   = "http://hass-timemachine.hass.svc:54000"
      launch_url      = "https://hass-timemachine.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/home-assistant.svg"
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
    # Traefik forward-auth + upstream Basic inject (OPENCODE_SERVER_PASSWORD).
    # Browser never sees OpenCode Basic — edge gate is Authentik.
    opencode = {
      name            = "OpenCode"
      external_host   = "https://code.dominiksiejak.pl"
      internal_host   = "http://lan-opencode.traefik.svc:4096"
      launch_url      = "https://code.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/opencode.svg"
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
      icon_url        = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/headlamp.svg"
      skip_path_regex = ""
    }
    # Policy Reporter UI (k8s Traefik IngressRoute + authentik middleware).
    # forward_single: outpost only auths; Traefik proxies to ClusterIP.
    policy-reporter = {
      name          = "Policy Reporter"
      external_host = "https://policy-reporter.dominiksiejak.pl"
      internal_host = "http://policy-reporter-ui.policy-reporter.svc:8080"
      launch_url    = "https://policy-reporter.dominiksiejak.pl"
      # No policy-reporter asset; Kyverno is the closest catalog match for the UI.
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
      icon_url        = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/qbittorrent.svg"
      skip_path_regex = ""
    }
    # *arr without native OIDC: Traefik forward-auth via proxy provider.
    bazarr = {
      name            = "Bazarr"
      external_host   = "https://bazarr.dominiksiejak.pl"
      internal_host   = "http://bazarr.mediabox.svc:6767"
      launch_url      = "https://bazarr.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/bazarr.svg"
      skip_path_regex = ""
    }
    profilarr = {
      name            = "Profilarr"
      external_host   = "https://profilarr.dominiksiejak.pl"
      internal_host   = "http://profilarr.mediabox.svc:6868"
      launch_url      = "https://profilarr.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/profilarr.svg"
      skip_path_regex = ""
    }
    prowlarr = {
      name            = "Prowlarr"
      external_host   = "https://prowlarr.dominiksiejak.pl"
      internal_host   = "http://prowlarr.mediabox.svc:9696"
      launch_url      = "https://prowlarr.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/prowlarr.svg"
      skip_path_regex = ""
    }
    sabnzbd = {
      name            = "SABnzbd"
      external_host   = "https://sabnzbd.dominiksiejak.pl"
      internal_host   = "http://gluetun.mediabox.svc:8085"
      launch_url      = "https://sabnzbd.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/sabnzbd.svg"
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
      icon_url   = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/unifi.svg"
    }
  }

  #───────────────────────────────────────────────────────────────────────────────
  # Access Control
  #───────────────────────────────────────────────────────────────────────────────

  # Jellyfin OIDC plugin maps Role Claim `groups` to Authentik group names `admins` and `users`.

  # Authentik user-library tiles for members of group `users` (family / brand tier).
  # Admins still get every app via admin_access.
  brand_user_apps = toset([
    "calibre-web-automated",
    "shelfmark",
    "homeassistant",
    "jellyfin",
    "seerr",
    "sure",
    "synology",
  ])

  user_accessible_apps = local.brand_user_apps
}
