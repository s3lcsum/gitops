# Polibiuro K C — static company site on Cloudflare Pages.
# Direct-upload project `polkc` (Workers & Pages), same pattern as miedzysztuka.
# Public host: polkc.dominiksiejak.pl → polkc.pages.dev
#
# The files live in this repo at sites/polkc/ (no private sibling repo yet).
# First deploy is a Pages Direct Upload; later `wrangler pages deploy sites/polkc --project-name=polkc`.
#
# If these already exist in the account, import before apply:
#   tofu import 'cloudflare_pages_project.polkc' '<account_id>/polkc'
#   tofu import 'cloudflare_pages_domain.polkc' '<account_id>/polkc/polkc.dominiksiejak.pl'

resource "cloudflare_pages_project" "polkc" {
  account_id        = var.cloudflare_account_id
  name              = "polkc"
  production_branch = "main"

  build_config = {
    build_caching   = true
    build_command   = ""
    destination_dir = "/"
    root_dir        = ""
  }

  deployment_configs = {
    preview    = {}
    production = {}
  }

  lifecycle {
    ignore_changes = [deployment_configs]
  }
}

resource "cloudflare_pages_domain" "polkc" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.polkc.name
  name         = "polkc.${var.zone_name}"
}

resource "cloudflare_dns_record" "polkc" {
  zone_id = cloudflare_zone.main.id
  name    = "polkc.${var.zone_name}"
  type    = "CNAME"
  content = "polkc.pages.dev"
  proxied = true
  ttl     = 1
}
