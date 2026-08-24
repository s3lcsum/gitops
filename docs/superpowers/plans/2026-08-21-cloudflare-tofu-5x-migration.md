# Cloudflare Module 5.x Migration + DNS Import — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate `terraform/cloudflare/main.tf` from the 4.x provider schema to 5.x, and codify 14 live `dominiksiejak.pl` zone DNS records as explicit `cloudflare_dns_record` resources.

**Architecture:** Rewrite `main.tf` to match the 5.22.0 provider schema (verified via `tofu providers schema`): `cloudflare_zone.account{id}`, tunnel `tunnel_secret`, tunnel config as `config = { ingress = [...] }` attribute (no more `dynamic` block), ruleset `rules = [...]` list, and `cloudflare_record` → `cloudflare_dns_record`. Then `tofu import` all existing live records so `apply` adopts them without recreating.

**Tech Stack:** OpenTofu v1.12.6, cloudflare/cloudflare provider 5.22.0, hashicorp/random 3.9.0.

## Global Constraints

- Provider pinned: cloudflare `5.22.0` (already declared in `providers.tf`); random `3.9.0`.
- `tofu`, not `terraform`. Auto-approves; pass extra flags via `TOFU_ARGS`.
- DNS value field in 5.x is **`content`** (confirmed by example resource.tf), not `value`.
- Records to EXCLUDE: root+www `pages.dev` CNAMEs, `homeassistant-atom` (tunnel-loop owned).
- Zone/records account: `e092ee6780d8a561afd1530702c0fd6a`. Zone: `f2369cb70da5fe1fbfda1743367dd7c3`.
- Token (certbot-issued, cfut_) works for the API: `~/.cloudflare/cloudflare.ini`.
- `*.dominiksiejak.pl` A record IP auto-changes ~monthly → **`lifecycle { ignore_changes = [content] }`**.
- Repo has MANY unrelated uncommitted changes — commit only specific files, never `git add .`.
- After migration, run `tofu validate` + `tofu fmt`, then `pre-commit run`.

---

## Task 0: Baseline & Backup

**Files:**
- Backup: `terraform/cloudflare/main.tf` (current mid-migration working tree)

- [ ] **Step 1: Back up the current file**

```bash
cp terraform/cloudflare/main.tf /tmp/cf-main-backup.tf
```

- [ ] **Step 2: Confirm provider installed**

```bash
tofu init -upgrade # ensures 5.22.0 locked in .terraform.lock.hcl
```

---

## Task 1: Rewrite main.tf to 5.x schema

**Files:**
- Rewrite: `terraform/cloudflare/main.tf`

**Interfaces:**
- Consumes: `var.cloudflare_account_id`, `var.zone_name`, `var.tunnel_name`, `var.tunnel_team_name`, `var.tunnel_apps`, `local.active_apps`, `local.web_apps`, `local.tcp_apps` (all unchanged)
- Produces: `cloudflare_zone.main`, `cloudflare_dns_record.<name>` for all records; `cloudflare_zero_trust_tunnel_cloudflared.homelab`, its `.config`, `cloudflare_zero_trust_access_application.tunnel`, `cloudflare_ruleset.lcountry`

**Step 1: Rewrite zone + ruleset block**

```hcl
resource "cloudflare_zone" "main" {
  account = { id = var.cloudflare_account_id }
  name    = var.zone_name
  type    = "full"
}

resource "cloudflare_ruleset" "country_allowlist" {
  zone_id     = cloudflare_zone.main.id
  kind        = "zone"
  phase       = "http_request_firewall_custom"
  name        = "dominiksiejak.pl country allowlist"
  description = "Block requests from countries other than Poland, Germany, Spain"

  rules = [{
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
  }]
}
```

**Step 2: Rewrite tunnel + access apps**

```hcl
resource "random_bytes" "tunnel_secret" {
  length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id    = var.cloudflare_account_id
  name          = var.tunnel_name
  config_src    = "cloudfledge"
  tunnel_secret = random_bytes.tunnel_secret.base64
}

resource "cloudflare_zero_trust_access_application" "tunnel" {
  for_each = local.web_apps
  zone_id = cloudflare_zone.main.id
  name    = "${each.key} public tunnel"
  domain  = each.key
  type    = "self_hosted"
  policies = [{ decision = "non_identity", precedence = 1 }]
}
```

**Step 3: Rewrite tunnel config** — list-style `config` (5.x), building `ingress` via comprehensions:

```hcl
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id

  config = {
    ingress = concat([
      for web in local.web_apps :
        {
          hostname = web
          service  = local.web_apps[web]
          origin_request = {
            access = {
              required  = true
              aud_tag   = [cloudflare_zero_trust_access_application.tunnel[web].aud]
              team_name = var.tunnel_team_name
            }
          }
        }
    ], [
      for tcp in local.tcp_apps :
        {
          hostname = tcp
          service  = local.tcp_apps[tcp]
        }
    ], [
      { service = "http_status:404" }
    ])
  }
}

# CNAMEs so traffic reaches the tunnel edge (unchanged except resource rename).
resource "cloudflare_dns_record" "tunnel" {
  for_each = local.active_apps
  zone_id  = cloudflare_zone.main.id
  name     = trimsuffix(each.key, ".${var.zone_name}")
  type     = "CNAME"
  content  = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied  = true
  ttl      = 1
}
```

---

## Task 2: Add 14 explicit DNS records

**Files:**
- Modify: `terraform/cloudflare/main.tf` (append at end)

**Interfaces:**
- Consumes: `cloudflare_zone.main.id`
- Produces: named dns records for import

**Add (append):**

```hcl
resource "cloudflare_dns_record" "wildcard" {
  zone_id     = cloudflare_zone.main.id
  name        = "*.dominiksiejak.pl"
  type        = "A"
  content     = "109.173.240.90"
  proxied     = false
  ttl         = 1
  lifecycle { ignore_changes = [content] }
}
resource "cloudflare_dns_record" "lake_wildcard" {
  zone_id     = cloudflare_zone.main.id
  name        = "*.lake.dominiksiejak.pl"
  type        = "A"
  content     = "192.168.89.254"
  proxied     = false
  ttl         = 1
}
resource "cloudflare_dns_record" "local_wildcard" {
  zone_id     = cloudflare_zone.main.id
  name        = "*.local.dominiksiejak.pl"
  type        = "A"
  content     = "127.0.0.1"
  proxied     = false
  ttl         = 1
}
resource "cloudflare_dns_record" "lake" {
  zone_id     = cloudflare_zone.main.id
  name        = "lake.dominiksiejak.pl"
  type        = "A"
  content     = "192.168.89.254"
  proxied     = false
  ttl         = 1
}
resource "cloudflare_dns_record" "zoho_verify" {
  zone_id     = cloudflare_zone.main.id
  name        = "zb79924229.mail.dominiksiejak.pl"
  type        = "CNAME"
  content     = "zmverify.zoho.eu"
  proxied     = false
  ttl         = 600
}
resource "cloudflare_dns_record" "mx_root_1" {
  zone_id     = cloudflare_zone.main.id
  name        = "dominiksiejak.pl"
  type        = "MX"
  content     = "route1.mx.cloudflare.net"
  priority    = 12
  proxied     = false
  ttl         = 1
}
resource "cloudflare_dns_record" "mx_root_2" {
  zone_id     = cloudflare_zone.main.id
  name        = "dominiksiejak.pl"
  type        = "MX"
  content     = "route2.mx.cloudflare.net"
  priority    = 26
  proxied     = false
  ttl         = 1
}
resource "cloudflare_dns_record" "mx_root_3" {
  zone_id     = cloudflare_zone.main.id
  name        = "dominiksiejak.pl"
  type        = "MX"
  content     = "route3.mx.cloudflare.net"
  priority    = 14
  proxied     = false
  ttl         = 1
}
resource "cloudflare_dns_record" "mx_mail_1" {
  zone_id     = cloudflare_zone.main.id
  name        = "mail.dominiksiejak.pl"
  type        = "MX"
  content     = "route1.mx.cloudflare.net"
  priority    = 12
  proxied     = false
  ttl         = 1
}
resource "cloudflare_dns_record" "mx_mail_2" {
  zone_id     = cloudflare_zone.main.id
  name        = "mail.dominiksiejak.pl"
  type        = "MX"
  content     = "route2.mx.cloudflare.net"
  priority    = 26
  proxied     = false
  ttl         = 1
}
resource "cloudflare_dns_record" "mx_mail_3" {
  zone_id     = cloudflare_zone.main.id
  name        = "mail.dominiksiejak.pl"
  type        = "MX"
  content     = "route3.mx.cloudflare.net"
  priority    = 14
  proxied     = false
  ttl         = 1
}
resource "cloudflare_dns_record" "dkim" {
  zone_id     = cloudflare_zone.main.id
  name        = "cf2024-1._domainkey.dominiksiejak.pl"
  type        = "TXT"
  content     = "v=DKIM1; h=sha256; k=rsa; p=DUS...fullkey..."
  proxied     = false
  ttl         = 1
}
resource "cloudflare_dns_record" "spf_root" {
  zone_id     = cloudflare_zone.main.id
  name        = "dominiksiejak.pl"
  type        = "TXT"
  content     = "v=spf1 include:_spf.mx.cloudflare.net ~all"
  proxied     = false
  ttl         = 1
}
resource "cloudflare_dns_record" "spf_mail" {
  zone_id     = cloudflare_zone.main.id
  name        = "mail.dominiksiejak.pl"
  type        = "TXT"
  content     = "v=spf1 include:_spf.mx.cloudflare.net ~all"
  proxied     = false
  ttl         = 1
}
```

MAJOR CAUTION: The DKIM record's full P= value must be copied EXACTLY (see `Live zone records` above). Do NOT truncate it in the committed file — the record above shows `p=...full tag` as a placeholder. The implementation must paste the full key from the live API output.

---

## Task 3: Validate & format

- [ ] **Step 1: Validate**

```bash
cd terraform/cloudflare
export CLOUDFLARE_API_TOKEN="<token from ./cloudflare.ini>"
tofu validate -var="cloudflare_account_id=e092ee6780d8a561afd1530702c0fd6a"
```

Fix any schema errors the validate surfaces (the provider binary is the source of truth).

- [ ] **Step 2: Format**

```bash
tofu fmt
```

- [ ] **Step 3: Pre-commit** (fast, targets only cloudflare)

```bash
pre-commit run terraform/cloudflare/main.tf
```

---

## Task 4: Import live records, plan, apply

**Files:**
- state: tofu cloud workspace `dominiksiejak/gitops-cloudflare`

- [ ] **Step 1: Import zone (if not present)** — `<zone_id>`

```bash
tofu import cloudflare_zone.main f2369cb70da5fe1fbfda1743367dd7c3
```

- [ ] **Step 2: Import each of the 14 records** — address `<zone_id>/<record_id>`

```bash
tofu import cloudflare_dns_record.wildcard f2369cb70da5fe1fbfda1743367dd7c3/<record_id_a>
```
(Repeat for wildcard A, lake_wild, local_wild, lake, zoho, 6 MX, dkim, spf_root, spf_mail — 14 total.)

- [ ] **Step 3: Plan** — expect ZERO changes for DNS, and any new tunnel/access resources appear

```bash
tofu plan -var="cloudflare_account_id=e092ee6780d8a561afd1530702c0fd6a"
```

- [ ] **Step 4: Apply**

```bash
tofu apply -var="cloudflare_account_id=e092ee6780d8a561afd1530702c0fd6a"
```

- [ ] **Step 5: Verify** — records unchanged, plan clean

```bash
curl -s -H "Authorization: Bearer $CF_TOKEN" ".../dns_records" # spot-check
```

---

## Post-Migration Notes

- The `.terraform.lock.hcl` provider version will be rewritten by `tofu init -upgrade`; commit it.
- If `tofu plan` shows the 14 DNS records being DELETEd before import, I imported in the wrong ORDER (adopt records BEFORE apply). Re-run apply only after imports succeed.
- The tunnel `config` block migration to the `ingress = [...]` list must preserve the Access JWT gate semantics exactly.
