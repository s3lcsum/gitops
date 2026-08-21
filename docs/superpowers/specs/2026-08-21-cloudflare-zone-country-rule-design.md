# Cloudflare: Manage zone + zone-wide country allowlist

Date: 2026-08-21

## Goal

In `terraform/cloudflare/`, adopt the `dominiksiejak.pl` zone as a managed resource
and add a zone-wide WAF security rule that allows access only from selected countries
(PL, DE, ES), blocking everything else.

## Context

- `variables.tf` already defaults `zone_name = "dominiksiejak.pl"`.
- `main.tf:1` currently only *looks up* the zone via `data "cloudflare_zone" "main"`.
  No security rules exist in the module.

## Design

### 1. Adopt the zone (main.tf)

Replace the `data "cloudflare_zone" "main"` lookup with a managed resource:

```hcl
resource "cloudflare_zone" "main" {
  zone = var.zone_name
  type = "primary"
}
```

- Reference updates: `data.cloudflare_zone.main.id` -> `cloudflare_zone.main.id`
  (used by the `cloudflare_record.tunnel` resources).

**Operational import step:** because the zone already exists in Cloudflare (records are
already created against it), a plain `apply` will error with "zone already exists". After
editing, import the live zone into state so tofu manages it rather than recreating it
(e.g. `tofu import` of the `cloudflare_zone.main` resource / provider adopt flow).

### 2. Zone-wide country WAF rule (new ruleset)

Add a `cloudflare_ruleset` attached to the zone:

- `kind = "zone"` so it applies to all proxied hostname records in the zone.
- `zone_id = cloudflare_zone.main.id`
- `phase = 1`
- One custom rule that blocks requests from any country not allowed:

```
ip.geoip.country not in {"PL" "DE" "ES"}
```

- Action: `block` -> HTTP 403 with a plain-text response body.
- `enabled = true`, descriptive `name`/`description`.

This restricts the entire `dominiksiejak.pl` zone (every endpoint behind the proxied
records), matching the requested scope.

## Decisions / trade-offs

- **Block (403)** chosen over *managed challenge* because the requirement is an explicit
  allowlist ("allows only selected countries"). If hard-blocking VPNs becomes an issue,
  switching to `challenge` is a one-line rule change.
- **Zone-wide** chosen over app-scoped: the ruleset is bound to the zone, so all proxied
  hostnames inherit the country restriction.

## Files changed

- `terraform/cloudflare/main.tf` — convert zone lookup to managed resource, add ruleset.
- Follow repo verification: `make check` (validate + fmt), `make plan` before `make apply`.
