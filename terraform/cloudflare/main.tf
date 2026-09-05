resource "cloudflare_zone" "main" {
  account = {
    id = var.cloudflare_account_id
  }
  name = var.zone_name
  type = "full"
}

# Zone-wide WAF rule: block requests from countries other than PL, DE, ES.
# Adopted from the dashboard's "Zone lockdown" custom ruleset (the only custom
# ruleset Cloudflare allows in the http_request_firewall_custom phase).
resource "cloudflare_ruleset" "country_allowlist" {
  zone_id = cloudflare_zone.main.id
  kind    = "zone"
  phase   = "http_request_firewall_custom"
  name    = "default"

  rules = [
    {
      ref         = "skip-messenger-webhook"
      action      = "skip"
      expression  = "(http.host eq \"n8n.dominiksiejak.pl\" and starts_with(http.request.uri.path, \"/webhook/messenger\")) or http.host in {\"dominiksiejak.pl\" \"www.dominiksiejak.pl\" \"miedzysztuka.dominiksiejak.pl\" \"url.dominiksiejak.pl\" \"cribfinder.dominiksiejak.pl\"}"
      description = "Allow Messenger webhook path + public sites to bypass the country allowlist"
      enabled     = true

      action_parameters = {
        ruleset = "current"
      }
    },
    {
      ref         = "block-non-allowlisted-countries"
      action      = "block"
      expression  = "not ip.geoip.country in {\"PL\" \"DE\" \"ES\"}"
      description = "Block non-allowlisted countries"
      enabled     = true
    }
  ]
}

# HTTP → HTTPS and WWW → root redirects, adopted from the dashboard's templates
# (the only zone ruleset allowed in the http_request_dynamic_redirect phase).
resource "cloudflare_ruleset" "redirects" {
  zone_id = cloudflare_zone.main.id
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"
  name    = "default"

  rules = [
    {
      ref         = "95b52fb7b1bb450dbebfb42cef43e5a3"
      action      = "redirect"
      description = "Redirect from HTTP to HTTPS [Template]"
      enabled     = true
      expression  = "(http.request.full_uri wildcard r\"http://*\")"

      action_parameters = {
        from_value = {
          preserve_query_string = false
          status_code           = 301
          target_url = {
            expression = "wildcard_replace(http.request.full_uri, r\"http://*\", r\"https://$${1}\")"
          }
        }
      }
    },
    {
      ref         = "75e3e902ae83499c86b0531a3cd07e13"
      action      = "redirect"
      description = "Redirect from WWW to Root [Template]"
      enabled     = true
      expression  = "(http.request.full_uri wildcard r\"https://www.*\")"

      action_parameters = {
        from_value = {
          preserve_query_string = false
          status_code           = 301
          target_url = {
            expression = "wildcard_replace(http.request.full_uri, r\"https://www.*\", r\"https://$${1}\")"
          }
        }
      }
    }
  ]
}

# 32-byte secret base64-encoded for Cloudflare Tunnel registration
resource "random_bytes" "tunnel_secret" {
  length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "Lake" {
  account_id    = var.cloudflare_account_id
  name          = var.tunnel_name
  config_src    = "cloudflare"
  tunnel_secret = random_bytes.tunnel_secret.base64
}

# Preserve the existing tunnel UUID/secret when the resource address was renamed
# homelab → Lake. Without this, apply would destroy and recreate the tunnel.
moved {
  from = cloudflare_zero_trust_tunnel_cloudflared.homelab
  to   = cloudflare_zero_trust_tunnel_cloudflared.Lake
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

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "Lake" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.Lake.id
  source     = "cloudflare"

  config = {
    ingress = local.tunnel_ingress
  }
}

moved {
  from = cloudflare_zero_trust_tunnel_cloudflared_config.homelab
  to   = cloudflare_zero_trust_tunnel_cloudflared_config.Lake
}

# Create CNAMEs on the zone so traffic reaches the tunnel edge.
resource "cloudflare_dns_record" "tunnel" {
  for_each = local.active_apps

  zone_id = cloudflare_zone.main.id
  name    = each.key
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.Lake.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

# LAN IP records for the lake platform (proxied off — internal addresses).
resource "cloudflare_dns_record" "lake_apex" {
  zone_id = cloudflare_zone.main.id
  name    = "lake.dominiksiejak.pl"
  type    = "A"
  content = "192.168.89.254"
  proxied = false
  ttl     = 1
}

resource "cloudflare_dns_record" "lake_wildcard" {
  zone_id = cloudflare_zone.main.id
  name    = "*.lake.dominiksiejak.pl"
  type    = "A"
  content = "192.168.89.254"
  proxied = false
  ttl     = 1
}

# Split-DNS local wildcard (127.0.0.1 = this host localhost).
resource "cloudflare_dns_record" "local_wildcard" {
  zone_id = cloudflare_zone.main.id
  name    = "*.local.dominiksiejak.pl"
  type    = "A"
  content = "127.0.0.1"
  proxied = false
  ttl     = 1
}

# Public homepage (Cloudflare Pages).
resource "cloudflare_dns_record" "pages_apex" {
  zone_id = cloudflare_zone.main.id
  name    = "dominiksiejak.pl"
  type    = "CNAME"
  content = "dominiksiejak.pages.dev"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "pages_www" {
  zone_id = cloudflare_zone.main.id
  name    = "www.dominiksiejak.pl"
  type    = "CNAME"
  content = "dominiksiejak.pages.dev"
  proxied = true
  ttl     = 1
}

# Atom home's separate tunnel endpoint.
resource "cloudflare_dns_record" "homeassistant_atom" {
  zone_id = cloudflare_zone.main.id
  name    = "homeassistant-atom.dominiksiejak.pl"
  type    = "CNAME"
  content = "4eb694bc-9af0-48b6-80e3-4e097b0b20f5.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

# Email SPF.
resource "cloudflare_dns_record" "spf_apex" {
  zone_id = cloudflare_zone.main.id
  name    = "dominiksiejak.pl"
  type    = "TXT"
  content = "\"v=spf1 include:_spf.mx.cloudflare.net ~all\""
  ttl     = 1
}

resource "cloudflare_dns_record" "spf_mail" {
  zone_id = cloudflare_zone.main.id
  name    = "mail.dominiksiejak.pl"
  type    = "TXT"
  content = "\"v=spf1 include:_spf.mx.cloudflare.net ~all\""
  ttl     = 1
}

# DKIM signing key (multi-part TXT content joined with a space).
resource "cloudflare_dns_record" "dkim" {
  zone_id = cloudflare_zone.main.id
  name    = "cf2024-1._domainkey.dominiksiejak.pl"
  type    = "TXT"
  content = "\"v=DKIM1; h=sha256; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiweykoi+o48IOGuP7GR3X0MOExCUDY/BCRHoWBnh3rChl7WhdyCxW3jgq1daEjPPqoi7sJvdg5hEQVsgVRQP4DcnQDVjGMbASQtrY4WmB1VebF+RPJB2ECPsEDTpeiI5ZyUAwJaVX7r6bznU67g7LvFq35yIo4sdlmtZGV+i0H4cpYH9+3JJ78k\" \"m4KXwaf9xUJCWF6nxeD+qG6Fyruw1Qlbds2r85U9dkNDVAS3gioCvELryh1TxKGiVTkg4wqHTyHfWsp7KD3WQHYJn0RyfJJu6YEmL77zonn7p2SRMvTMP3ZEXibnC9gz3nnhR6wcYL8Q7zXypKTMD58bTixDSJwIDAQAB\""
  ttl     = 1
}

# Zoho mailbox verification CNAME.
resource "cloudflare_dns_record" "zoho_verify" {
  zone_id = cloudflare_zone.main.id
  name    = "zb79924229.mail.dominiksiejak.pl"
  type    = "CNAME"
  content = "zmverify.zoho.eu"
  ttl     = 600
}

# Personal website (Hugo) on Cloudflare Pages.
resource "cloudflare_pages_project" "dominiksiejak" {
  account_id = var.cloudflare_account_id
  # Must match the live *.pages.dev hostname (dominiksiejak.pages.dev).
  # Import the existing project before first apply:
  #   tofu import 'cloudflare_pages_project.dominiksiejak' '<account_id>/dominiksiejak'
  name              = "dominiksiejak"
  production_branch = "main"

  build_config = {
    build_caching   = true
    build_command   = "hugo"
    destination_dir = "public"
    root_dir        = ""
  }

  deployment_configs = {
    preview = {}
    production = {
      env_vars = {
        HUGO_VERSION = {
          type  = "plain_text"
          value = "0.165.0"
        }
      }
    }
  }

  source = {
    type = "github"
    config = {
      owner                          = "s3lcsum"
      repo_name                      = "website"
      production_branch              = "main"
      production_deployments_enabled = true
      preview_deployment_setting     = "none"
    }
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "cloudflare_pages_domain" "apex" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.dominiksiejak.name
  name         = var.zone_name
}

resource "cloudflare_pages_domain" "www" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.dominiksiejak.name
  name         = "www.${var.zone_name}"
}
