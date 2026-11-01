# Cribfinder is an OpenNext Next.js app on Cloudflare Workers (not Pages).
# Git deploys stay with Workers Builds / wrangler; this module adopts the
# Worker identity, custom hostname, and the production listings KV namespace.
# Catalog contents (catalog:v1) are owned by the app / wrangler kv put — not
# tofu — so a listings dump never lands in this public repo.
#
# There is no cloudflare_pages_project named cribfinder — only the Hugo
# personal site uses Pages. Public URL is the Workers custom domain below.
# DNS AAAA 100:: for cribfinder.dominiksiejak.pl is owned by that domain
# (read-only in the zone API); do not add a parallel cloudflare_dns_record.

import {
  to = cloudflare_worker.cribfinder
  id = "${local.cfg.cloudflare_account_id}/d63267fd5d9f4ce1ab238d5aee91caf8"
}

import {
  to = cloudflare_workers_custom_domain.cribfinder
  id = "${local.cfg.cloudflare_account_id}/186bfbfbaa90467df5ea680eecbcdcaadb580a69"
}

import {
  to = cloudflare_workers_kv_namespace.cribfinder_listings
  id = "${local.cfg.cloudflare_account_id}/f06e75fdbeec4759b8ecc6b06caab698"
}

resource "cloudflare_worker" "cribfinder" {
  account_id = local.cfg.cloudflare_account_id
  name       = "cribfinder"

  # Bundle, bindings, and Git builds are owned by wrangler / Workers Builds.
  lifecycle {
    ignore_changes = all
  }
}

resource "cloudflare_workers_custom_domain" "cribfinder" {
  account_id = local.cfg.cloudflare_account_id
  hostname   = "cribfinder.${local.cfg.zone_name}"
  service    = cloudflare_worker.cribfinder.name
  zone_id    = cloudflare_zone.main.id
}

resource "cloudflare_workers_kv_namespace" "cribfinder_listings" {
  account_id = local.cfg.cloudflare_account_id
  title      = "cribfinder-listings"
}
