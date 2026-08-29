# Między sztuką a nauką — static event site on Cloudflare Pages.
# Git deploys from s3lcsum/miedzysztuka (no build step; HTML/CSS/JS at repo root).
# This is a Pages project (same pattern as the Hugo personal site), not a
# standalone Worker like cribfinder. It shows up under Workers & Pages.
#
# The GitHub repo is currently empty — the first production deploy happens
# on the first push to `main`. Cloudflare's GitHub App must include this
# private repo (Dashboard → Workers & Pages → Create → Connect to Git).

resource "cloudflare_pages_project" "miedzysztuka" {
  account_id        = var.cloudflare_account_id
  name              = "miedzysztuka"
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
      repo_name                      = "miedzysztuka"
      production_branch              = "main"
      production_deployments_enabled = true
      preview_deployment_setting     = "none"
    }
  }

  lifecycle {
    ignore_changes = [deployment_configs]
  }
}

resource "cloudflare_pages_domain" "miedzysztuka" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.miedzysztuka.name
  name         = "miedzysztuka.${var.zone_name}"
}

resource "cloudflare_dns_record" "miedzysztuka" {
  zone_id = cloudflare_zone.main.id
  name    = "miedzysztuka.${var.zone_name}"
  type    = "CNAME"
  content = "miedzysztuka.pages.dev"
  proxied = true
  ttl     = 1
}
