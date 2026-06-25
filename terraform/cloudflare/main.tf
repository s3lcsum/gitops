data "cloudflare_zone" "main" {
  name = var.zone_name
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

  zone_id = data.cloudflare_zone.main.id
  name    = trimsuffix(each.key, ".${var.zone_name}")
  type    = "CNAME"
  value   = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}
