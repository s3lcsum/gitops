# Non-secret defaults. Secret: local.secret.cloudflare_api_token (ephemeral).
locals {
  cfg = {
    cloudflare_account_id = "e092ee6780d8a561afd1530702c0fd6a"
    zone_name             = "dominiksiejak.pl"
    tunnel_name           = "homelab"
    tunnel_team_name      = "dominiksiejak"
    # Traefik-backed hosts: A @ WAN (external-dns-cloudflare) + dnsrewrite @ .252
    # (external-dns-adguard). Do not duplicate as tunnel CNAMEs here.
    tunnel_apps = {
      "homeassistant-atom.dominiksiejak.pl" = ""
      "dns.dominiksiejak.pl"                = ""
    }
  }
}
