locals {
  organizations = {
    "dominiksiejak" = {
      name = "dominiksiejak"
    }
    "mirrors" = {
      name = "mirrors"
    }
  }

  mirrors = {
    "mirrors/act_runner"                    = { clone_url = "https://gitea.com/gitea/act_runner.git" }
    "mirrors/AdGuardHome"                   = { clone_url = "https://github.com/AdguardTeam/AdGuardHome.git" }
    "mirrors/adminer"                       = { clone_url = "https://github.com/vrana/adminer.git" }
    "mirrors/All-jellyfin-media-server"     = { clone_url = "https://github.com/Morzomb/All-jellyfin-media-server.git" }
    "mirrors/Authentik"                     = { clone_url = "https://github.com/goauthentik/authentik.git" }
    "mirrors/backstage"                     = { clone_url = "https://github.com/backstage/backstage.git" }
    "mirrors/Bazarr"                        = { clone_url = "https://github.com/morpheus65535/bazarr.git" }
    "mirrors/Calibre"                       = { clone_url = "https://github.com/kovidgoyal/calibre.git" }
    "mirrors/Cloudflared"                   = { clone_url = "https://github.com/cloudflare/cloudflared.git" }
    "mirrors/crowdsec"                      = { clone_url = "https://github.com/crowdsecurity/crowdsec.git" }
    "mirrors/CUPS"                          = { clone_url = "https://github.com/OpenPrinting/cups.git" }
    "mirrors/DIUN"                          = { clone_url = "https://github.com/crazy-max/diun.git" }
    "mirrors/docker-adminer"                = { clone_url = "https://git.hubp.de/TimWolla/docker-adminer.git" }
    "mirrors/docker-bazarr"                 = { clone_url = "https://github.com/linuxserver/docker-bazarr.git" }
    "mirrors/docker-calibre"                = { clone_url = "https://github.com/linuxserver/docker-calibre.git" }
    "mirrors/docker-idrac6"                 = { clone_url = "https://github.com/DomiStyle/docker-idrac6.git" }
    "mirrors/docker-jellyfin"               = { clone_url = "https://github.com/linuxserver/docker-jellyfin.git" }
    "mirrors/docker-prowlarr"               = { clone_url = "https://github.com/linuxserver/docker-prowlarr.git" }
    "mirrors/docker-qbittorrent"            = { clone_url = "https://github.com/linuxserver/docker-qbittorrent.git" }
    "mirrors/docker-radarr"                 = { clone_url = "https://github.com/linuxserver/docker-radarr.git" }
    "mirrors/docker-sabnzbd"                = { clone_url = "https://github.com/linuxserver/docker-sabnzbd.git" }
    "mirrors/docker-sonarr"                 = { clone_url = "https://github.com/linuxserver/docker-sonarr.git" }
    "mirrors/WatchYourLAN"                  = { clone_url = "https://github.com/aceberg/WatchYourLAN.git" }
    "mirrors/dozzle"                        = { clone_url = "https://github.com/amir20/dozzle.git" }
    "mirrors/error-pages"                   = { clone_url = "https://github.com/tarampampam/error-pages.git" }
    "mirrors/FlareSolverr"                  = { clone_url = "https://github.com/FlareSolverr/FlareSolverr.git" }
    "mirrors/gitea"                         = { clone_url = "https://github.com/go-gitea/gitea.git" }
    "mirrors/Gluetun"                       = { clone_url = "https://github.com/qdm12/gluetun.git" }
    "mirrors/Jellyfin"                      = { clone_url = "https://github.com/jellyfin/jellyfin.git" }
    "mirrors/Jellyseerr"                    = { clone_url = "https://github.com/Fallenbagel/jellyseerr.git" }
    "mirrors/n8n"                           = { clone_url = "https://github.com/n8n-io/n8n.git" }
    "mirrors/netboot.xyz"                   = { clone_url = "https://github.com/netbootxyz/netboot.xyz.git" }
    "mirrors/NetBox"                        = { clone_url = "https://github.com/netbox-community/netbox.git" }
    "mirrors/olbat-dockerfiles"             = { clone_url = "https://github.com/olbat/dockerfiles.git" }
    "mirrors/postgres_exporter"             = { clone_url = "https://github.com/prometheus-community/postgres_exporter.git" }
    "mirrors/PostgreSQL"                    = { clone_url = "https://github.com/postgres/postgres.git" }
    "mirrors/pre-commit-hooks"              = { clone_url = "https://github.com/pre-commit/pre-commit-hooks.git" }
    "mirrors/pre-commit-opentofu"           = { clone_url = "https://github.com/tofuutils/pre-commit-opentofu.git" }
    "mirrors/pre-commit-terraform"          = { clone_url = "https://github.com/antonbabenko/pre-commit-terraform.git" }
    "mirrors/Prowlarr"                      = { clone_url = "https://github.com/Prowlarr/Prowlarr.git" }
    "mirrors/qBittorrent"                   = { clone_url = "https://github.com/qbittorrent/qBittorrent.git" }
    "mirrors/Radarr"                        = { clone_url = "https://github.com/Radarr/Radarr.git" }
    "mirrors/SABnzbd"                       = { clone_url = "https://github.com/sabnzbd/sabnzbd.git" }
    "mirrors/Sonarr"                        = { clone_url = "https://github.com/Sonarr/Sonarr.git" }
    "mirrors/synthetic-monitoring-agent"    = { clone_url = "https://github.com/grafana/synthetic-monitoring-agent.git" }
    "mirrors/terraform-provider-authentik"  = { clone_url = "https://github.com/goauthentik/terraform-provider-authentik.git" }
    "mirrors/terraform-provider-b2"         = { clone_url = "https://github.com/Backblaze/terraform-provider-b2.git" }
    "mirrors/terraform-provider-gitea"      = { clone_url = "https://gitea.com/gitea/terraform-provider-gitea.git" }
    "mirrors/terraform-provider-google"     = { clone_url = "https://github.com/hashicorp/terraform-provider-google.git" }
    "mirrors/terraform-provider-netbox"     = { clone_url = "https://github.com/e-breuninger/terraform-provider-netbox.git" }
    "mirrors/terraform-provider-portainer"  = { clone_url = "https://github.com/portainer/terraform-provider-portainer.git" }
    "mirrors/terraform-provider-postgresql" = { clone_url = "https://github.com/cyrilgdn/terraform-provider-postgresql.git" }
    "mirrors/terraform-provider-proxmox"    = { clone_url = "https://github.com/bpg/terraform-provider-proxmox.git" }
    "mirrors/terraform-provider-random"     = { clone_url = "https://github.com/hashicorp/terraform-provider-random.git" }
    "mirrors/terraform-provider-routeros"   = { clone_url = "https://github.com/terraform-routeros/terraform-provider-routeros.git" }
    "mirrors/terraform-provider-tfe"        = { clone_url = "https://github.com/hashicorp/terraform-provider-tfe.git" }
    "mirrors/terraform-provider-vault"      = { clone_url = "https://github.com/hashicorp/terraform-provider-vault.git" }
    "mirrors/terraform-provider-wireguard"  = { clone_url = "https://github.com/OJFord/terraform-provider-wireguard.git" }
    "mirrors/Traefik"                       = { clone_url = "https://github.com/traefik/traefik.git" }
    "mirrors/UpSnap"                        = { clone_url = "https://github.com/seriousm4x/UpSnap.git" }
    "mirrors/uptime-kuma"                   = { clone_url = "https://github.com/louislam/uptime-kuma.git" }
    "mirrors/valkey"                        = { clone_url = "https://github.com/valkey-io/valkey.git" }
    "mirrors/valkey-container"              = { clone_url = "https://github.com/valkey-io/valkey-container.git" }
    "mirrors/Vault"                         = { clone_url = "https://github.com/hashicorp/vault.git" }
    "mirrors/Vaultwarden"                   = { clone_url = "https://github.com/dani-garcia/vaultwarden.git" }
    "mirrors/Warracker"                     = { clone_url = "https://github.com/sassanix/warracker.git" }
  }
}
