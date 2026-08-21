resource "cloudflare_zone" "main" {
  account_id = var.cloudflare_account_id
  zone       = var.zone_name
  type       = "full"
}

# Zone-wide WAF rule: allow access only from selected countries (PL, DE, ES).
resource "cloudflare_ruleset" "country_allowlist" {
  zone_id     = cloudflare_zone.main.id
  kind        = "zone"
  phase       = "http_request_firewall_custom"
  name        = "dominiksiejak.pl country allowlist"
  description = "Block requests from countries other than Poland, Germany, Spain"

  rules {
    action      = "block"
    expression  = "ip.geoip.country not in {\"PL\" \"DE\" \"ES\"}"
    description = "Block non-allowlisted countries"
    enabled     = true

    action_parameters {
      response {
        status_code  = 403
        content      = "blocked"
        content_type = "text/plain"
      }
    }
  }
}

# 32-byte secret base64-encoded for Cloudflare Tunnel registration
resource "random_bytes" "tunnel_secret" {
  length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id = var.cloudflare_account_id
  name       = var.tunnel_name
  secret     = random_bytes.tunnel_secret.base64
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id

  config {
    dynamic "ingress_rule" {
      for_each = local.active_apps
      content {
        hostname = ingress_rule.key
        service  = ingress_rule.value
      }
    }

    # Catch-all: returns 404 for any unmatched hostname
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# Create CNAMEs on the zone so traffic reaches the tunnel edge.
resource "cloudflare_record" "tunnel" {
  for_each = local.active_apps

  zone_id = cloudflare_zone.main.id
  name    = trimsuffix(each.key, ".${var.zone_name}")
  type    = "CNAME"
  value   = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}
