# Codify dominiksiejak.pl DNS records in terraform/cloudflare

## Goal

Adopt the remaining live DNS records of the `dominiksiejak.pl` zone into the
`terraform/cloudflare` module so they're version-controlled, while leaving
externally-managed records alone.

## Excluded records

These stay out of terraform:

- `dominiksiejak.pl` CNAME → `website-f2a.pages.dev` (Pages site, not managed here)
- `www.dominiksiejak.pl` CNAME → `website-f2a.pages.dev` (same)
- `homeassistant-atom.dominiksiejak.pl` CNAME → tunnel (already owned by the
  existing `for_each` tunnel resource loop)

## Records to manage (13)

All effectively `cloudflare_record` resources added explicitly in `main.tf`
(grouped after the tunnel section).

### A records (proxied=false, ttl=1)

| name | value | notes |
|---|---|---|
| `*.dominiksiejak.pl` | `109.173.240.90` | **`ignore_content = true`** — IP auto-updates externally every few weeks; tofu must not revert drift |
| `*.lake.dominiksiejak.pl` | `192.168.89.254` | |
| `*.local.dominiksiejak.pl` | `127.0.0.1` | |
| `lake.dominiksiejak.pl` | `192.168.89.254` | |

### CNAME

| name | value | ttl |
|---|---|---|
| `zb79924229.mail.dominiksiejak.pl` | `zmverify.zoho.eu` | 600 |

### MX (proxied=false, ttl=1)

Both `dominiksiejak.pl` and `mail.dominiksiejak.pl`, three records each:
`route1.mx.cloudflare.net` prio 12, `route2.mx.cloudflare.net` prio 26,
`route3.mx.cloudflare.net` prio 14.

### TXT (proxied=false, ttl=1)

| name | value |
|---|---|
| `cf2024-1._domainkey.dominiksiejak.pl` | DKIM record |
| `dominiksiejak.pl` | `v=spf1 include:_spf.mx.cloudflare.net ~all` |
| `mail.dominiksiejak.pl` | `v=spf1 include:_spf.mx.cloudflare.net ~all` |

## Import strategy

All 13 records already exist live. Adding the resources without importing
would cause `apply` to fail ("record already exists"). Before `apply`, adopt
each into state via `tofu import` using the zone/record IDs already fetched
(address = `<zone_id>/<record_id>`).

## Verification

- `tofu plan` → zero drift against live state after import+apply
- `make check` (validate + fmt) passes
- `pre-commit run --all-files` passes
