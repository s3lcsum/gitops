# Non-secret defaults. Secret: local.secret.cloudflare_api_token (ephemeral).
locals {
  cfg = {
    cloudflare_account_id = "e092ee6780d8a561afd1530702c0fd6a"
    zone_name             = "dominiksiejak.pl"
    tunnel_name           = "homelab"
    tunnel_team_name      = "dominiksiejak"
    tunnel_apps = {
      "homeassistant-atom.dominiksiejak.pl" = ""
      "dns.dominiksiejak.pl"                = ""
      "n8n.dominiksiejak.pl"                = "https://traefik"
      "auth.dominiksiejak.pl"               = "https://traefik"
      "hass.dominiksiejak.pl"               = "https://traefik"
    }
  }
}
