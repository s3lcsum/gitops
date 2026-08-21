resource "cloudflare_zone" "main" {
  account = {
    id = var.cloudflare_account_id
  }
  name = var.zone_name
  type = "full"
}

# Zone-wide WAF rule: allow access only from selected countries (PL, DE, ES).
resource "cloudflare_ruleset" "country_allowlist" {
  zone_id     = cloudflare_zone.main.id
  kind        = "zone"
  phase       = "http_request_firewall_custom"
  name        = "dominiksiejak.pl country allowlist"
  description = "Block requests from countries other than Poland, Germany, Spain"

  rules = [
    {
      action      = "block"
      expression  = "ip.geoip.country not in {\"PL\" \"DE\" \"ES\"}"
      description = "Block non-allowlisted countries"
      enabled     = true

      action_parameters = {
        response = {
          status_code  = 403
          content      = "blocked"
          content_type = "text/plain"
        }
      }
    }
  ]
}

# 32-byte secret base64-encoded for Cloudflare Tunnel registration
resource "random_bytes" "tunnel_secret" {
  length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id    = var.cloudflare_account_id
  name          = var.tunnel_name
  config_src    = "cloudflare"
  tunnel_secret = random_bytes.tunnel_secret.base64
}

# Access application per public web host. Each enforces a Cloudflare Access policy at
# the edge for that hostname and yields the `aud` audience tag the tunnel config's JWT
# gate checks. `non_identity` = "open" (no CF login prompt; apps do their own auth).
resource "cloudflare_zero_trust_access_application" "tunnel" {
  for_each = local.web_apps

  zone_id = cloudflare_zone.main.id
  name    = "${each.key} public tunnel"
  domain  = each.key
  type    = "self_hosted"

  policies = [{
    decision   = "non_identity"
    precedence = 1
    include    = [{ everyone = {} }]
  }]
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
  source     = "cloudflare"

  config = {
    ingress = local.tunnel_ingress
  }
}

# Create CNAMEs on the zone so traffic reaches the tunnel edge.
resource "cloudflare_dns_record" "tunnel" {
  for_each = local.active_apps

  zone_id = cloudflare_zone.main.id
  name    = each.key
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}
