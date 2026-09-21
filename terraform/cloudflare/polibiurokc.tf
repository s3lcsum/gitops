# Polibiuro K C — static company site on Cloudflare Pages.
# Git deploys from s3lcsum/polibiurokc (no build step; HTML/CSS/JS at repo root).
# Same pattern as miedzysztuka / the Hugo personal site.
#
# The GitHub repo is private. Cloudflare's GitHub App must include it
# (Dashboard → Workers & Pages → Create → Connect to Git) before the first
# production deploy on push to `main`.

resource "cloudflare_pages_project" "polibiurokc" {
  account_id        = var.cloudflare_account_id
  name              = "polibiurokc"
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

  source = {
    type = "github"
    config = {
      owner                          = "s3lcsum"
      repo_name                      = "polibiurokc"
      production_branch              = "main"
      production_deployments_enabled = true
      preview_deployment_setting     = "none"
    }
  }

  lifecycle {
    ignore_changes = [deployment_configs]
  }
}

resource "cloudflare_pages_domain" "polibiurokc" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.polibiurokc.name
  name         = "polibiurokc.${var.zone_name}"
}

resource "cloudflare_dns_record" "polibiurokc" {
  zone_id = cloudflare_zone.main.id
  name    = "polibiurokc.${var.zone_name}"
  type    = "CNAME"
  content = "polibiurokc.pages.dev"
  proxied = true
  ttl     = 1
}
