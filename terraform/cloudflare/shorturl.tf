# Short URL redirector (https://url.dominiksiejak.pl).
# Destinations live in Workers KV (LINKS / links:v1). The Worker script is
# deployed with wrangler (shorturl.js + shorturl.wrangler.jsonc); terraform
# adopts the Worker identity, custom hostname, namespace, and public catalog.
# Do not put phone numbers or other PII in shorturl-links.json.

import {
  to = cloudflare_worker.shorturl
  id = "${var.cloudflare_account_id}/69ed228886f5494d8f58b1ff232f847f"
}

import {
  to = cloudflare_workers_custom_domain.shorturl
  id = "${var.cloudflare_account_id}/5508f07598ab19a09e1090745fd0d53ff1fc0350"
}

import {
  to = cloudflare_workers_kv_namespace.shorturl_links
  id = "${var.cloudflare_account_id}/9b577555a3b0459eb5cbacd381ded154"
}

import {
  to = cloudflare_workers_kv.shorturl_links
  id = "${var.cloudflare_account_id}/9b577555a3b0459eb5cbacd381ded154/links:v1"
}

resource "cloudflare_worker" "shorturl" {
  account_id = var.cloudflare_account_id
  name       = "shorturl"

  # Script + KV binding are owned by wrangler deploy.
  lifecycle {
    ignore_changes = all
  }
}

resource "cloudflare_workers_custom_domain" "shorturl" {
  account_id = var.cloudflare_account_id
  hostname   = "url.${var.zone_name}"
  service    = cloudflare_worker.shorturl.name
  zone_id    = cloudflare_zone.main.id
}

resource "cloudflare_workers_kv_namespace" "shorturl_links" {
  account_id = var.cloudflare_account_id
  title      = "shorturl-links"
}

resource "cloudflare_workers_kv" "shorturl_links" {
  account_id   = var.cloudflare_account_id
  namespace_id = cloudflare_workers_kv_namespace.shorturl_links.id
  key_name     = "links:v1"
  value        = file("${path.module}/shorturl-links.json")
}
