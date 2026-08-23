# Phone Firewall Page — `enter.dominiksiejak.pl`

**Date:** 2026-08-23
**Status:** Approved
**Author:** opencode

---

## Overview

A phone-friendly web page at `https://enter.dominiksiejak.pl` that lets any authenticated user add their IP address to the RouterOS firewall allowlist (`allowed-wan` address list) with auto-expiring TTL. Authentication is handled by Authentik SSO at the Traefik layer — no secret token is shared with n8n.

---

## Components

### 1. Traefik Router

New router rule in `stacks/traefik/dynamic.yaml` (or a docker label on the n8n container) routing `enter.dominiksiejak.pl` to n8n through the `authentik@docker` middleware:

```yaml
routers:
  enter:
    rule: "Host(`enter.dominiksiejak.pl`)"
    entryPoints:
      - websecure
    middlewares:
      - authentik@docker
    service: n8n
```

n8n must be reachable from Traefik via the `proxy` network (it already is).

### 2. n8n Workflow A — Serve Page

**Trigger:** Webhook node (`GET /webhook/firewall-page`)

**Steps:**
1. **Respond to Webhook** — return `200` with `Content-Type: text/html` and the HTML page (inline CSS/JS).

The page will **not** contain a secret code field. It reads the logged-in user from the Authentik-forwarded header (`X-Authentik-Name`) to display "Logged in as: ...".

### 3. n8n Workflow B — Add IP

**Trigger:** Webhook node (`POST /webhook/firewall`)

**Steps:**
1. **IF node** — check Authentik identity headers are present (`X-Authentik-User` or `X-Authentik-Name`). If missing → respond `403`.
2. **IF node** — validate IP is a valid IPv4 (regex).
3. **HTTP Request** — add entry to RouterOS:
   - `POST {{ $env.ROUTEROS_API_URL }}/rest/ip/firewall/address-list`
   - Auth header `Authorization: Basic <base64(user:pass)>`
   - Body: `{ "list": "allowed-wan", "address": "<ip>", "comment": "ttl:<unix_ms>" }`
   - `<unix_ms>` = `now + TTL` (1d / 7d / 30d)
4. **Respond to Webhook** — `{ "ok": true, "ip": "...", "expires": "<ISO timestamp>" }`

### 4. Cleanup Workflow (Scheduled)

**Trigger:** Schedule node, every 5 minutes.

**Steps:**
1. **HTTP Request** — `GET {ROUTEROS_API_URL}/rest/ip/firewall/address-list?list=allowed-wan`
2. **Code node** — filter entries where `comment` starts with `ttl:` and payload is in the past.
3. **Loop + HTTP Request** — `DELETE {ROUTEROS_API_URL}/rest/ip/firewall/address-list/{id}` for each expired entry.
4. **Log** — optional: count of removed entries.

---

## Authentication & Trust Model

- Authentik SSO is enforced **only** at the Traefik proxy layer for the `enter.` route.
- n8n trusts the presence of Authentik `X-Authentik-*` forwarded headers. This is safe **only if** `/webhook/firewall*` is unreachable via any other path.
- **Enforcement:** The n8n hostname (`n8n.dominiksiejak.pl`) must block/redirect requests to `/webhook/firewall*` and n8n must not be directly reachable from the internet outside the `enter.` route. This prevents header spoofing.
- **Decision:** Any authenticated user may add an IP (no admin-group restriction).

---

## Environment Variables (n8n)

| Variable | Description |
|---|---|
| `ROUTEROS_API_URL` | RouterOS REST API base URL |
| `ROUTEROS_API_USER` | RouterOS API user with write access |
| `ROUTEROS_API_PASS` | RouterOS API password |

No shared-secret variable.

---

## TTL / Cleanup

- TTL values exposed as buttons: `1d`, `7d`, `30d`.
- Router entry `comment = "ttl:<unix_ms>"`.
- Cleanup runs every 5 minutes, removes `ttl:`-tagged entries past their expiry.

---

## Security Notes

- No token in request bodies or URLs.
- RouterOS credentials stored only as n8n env vars.
- Responses contain no secrets; minimal success/error messages.
- Must verify the router API path available to n8n (see Open Questions).

---

## Open Questions (resolved or deferred to implementation)

1. **RouterOS API reachability from n8n container:** The router runs at `192.168.89.1`. n8n (in a docker container on portainer) needs network path. Decide during implementation: route via Traefik's `router.dominiksiejak.pl` reverse proxy, or set up a dedicated RouterOS API user and expose the REST port to n8n's network. Simplest: HTTP Request to `https://router.dominiksiejak.pl/rest/...` through the existing proxy.
2. **n8n live host for webhooks:** Confirm `n8n.dominiksiejak.pl` is the live host for the workflows/webhooks we deploy to (earlier flagged MCP target `nodemation.*` was 404).