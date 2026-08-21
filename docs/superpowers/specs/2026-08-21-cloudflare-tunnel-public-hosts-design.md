# Cloudflare Zero Trust tunnel: expose n8n / auth / hass to external users

Date: 2026-08-21

## Goal

Make `n8n.dominiksiejak.pl`, `auth.dominiksiejak.pl`, and `hass.dominiksiejak.pl`
reachable from **outside the VPN** (e.g. public DNS like 1.1.1.1) through the existing
Cloudflare Zero Trust named tunnel (`cloudflared tunnel run`, tunnel name `homelab`),
which re-originates traffic to Traefik on the homelab, which routes each host to its
backend. Internal / on-VPN users are unaffected: their DNS resolves locally to Traefik
directly and never touches Cloudflare.

Transport between cloudflared and Traefik must be **encrypted (HTTPS)**.

## Context

- Tunnel is a Named/Zero-Trust tunnel managed by `stacks/cloudflared` (container) +
  `terraform/cloudflare/`. Tunnel ingress rules + CNAME records are driven by the
  map `var.tunnel_apps` in `variables.tf`, filtered to non-empty origins in `locals.tf`
  (`local.active_apps`).
- `main.tf` already has:
  - `cloudflare_zero_trust_tunnel_cloudflared.homelab`
  - `cloudflare_zero_trust_tunnel_cloudflared_config.homelab` with a `dynamic ingress_rule`
    per `local.active_apps` entry (`hostname` + `service`) plus an `http_status:404` catch-all.
  - `cloudflare_record.tunnel` (CNAME `*.cfargotunnel.com`, proxied) per active app.
- Currently only `firebird.dominiksiejak.pl` is active (`tcp://v-maintenance-firebird:3050`).
- Traefik v3.7.11:
  - `web` entrypoint on `:80` **308-redirects all hosts to HTTPS** (traefik.yaml:11).
  - `websecure` on `:443` is the HTTPS entrypoint, terminates the Let's Encrypt wildcard
    cert `*.dominiksiejak.pl`, routes by Host header.
- Traefik + cloudflared run on the same Portainer host. Traefik is on the synthetic
  `proxy` docker network. cloudflared currently has **no** network join (only its own
  default network), so it cannot resolve the `traefik` container by name today.
- Cloudflare **Access Application** objects are required to serve self-hosted hostnames
  over HTTP through a zero-trust named tunnel. The resource is
  `cloudflare_zero_trust_access_application` (type `self_hosted`).

## mTLS finding (why origin-side client certs are out)

Traefik supports mTLS (`tls.options.<name>.clientAuth.clientAuthType` ==
`RequireAndVerifyClientCert`, CA via `caFiles`). However, a **Named/Zero-Trust tunnel
connector (`cloudflared`) has no field to present a client certificate to the origin**;
Authenticated Origin Pull / mTLS is documented by Cloudflare as **not compatible with
cloudflared named tunnels**. Therefore we cannot do literal mTLS at the Traefik origin.
It is also not necessary as a primary boundary, because with a named tunnel the peer
Traefik sees is the local connector, not a random public client. We still achieve
encrypted transport + host/policy isolation, and optionally a connector-side JWT gate.

## Design

### 1. `terraform/cloudflare/variables.tf` — extend `tunnel_apps`

Add three entries (currently only `firebird` exists). Each maps a public hostname to
Traefik's HTTPS origin **by container name** (resolved because of change #3):

```
"n8n.dominiksiejak.pl"  = "https://traefik"
"auth.dominiksiejak.pl" = "https://traefik"
"hass.dominiksiejak.pl" = "https://traefik"
```

`local.active_apps` then includes them → tunnel ingress rules + CNAME records.

### 2. `terraform/cloudflare/main.tf` — Access applications

Add three `cloudflare_zero_trust_access_application` resources (type `self_hosted`),
one per host, each with:

- `name` (e.g. "n8n public tunnel", etc.)
- `domain` = `<host>.dominiksiejak.pl`
- `policies = [{ decision = "non_identity" }]` — "open" (no Cloudflare Access login);
  the apps do their own authentication (Authentik / n8n / HA).

The ingress rules in the config point to the HTTPS origin. Optionally, on each ingress
rule, add an `origin_request.access` gate (`required = true`, `aud_tag`) so cloudflared
drops requests lacking a valid CF Access JWT (defense-in-depth; "verify it really came
through Cloudflare", enforced by the connector rather than Traefik).

### 3. `stacks/cloudflared/compose.yaml` — join `proxy` network

So `cloudflared` resolves the `traefik` container by name:

- add a `networks: - proxy` entry to the `cloudflared` service
- declare `proxy: { external: true }` under the top-level `networks:` (if not already).

### 4. Encryption / origin routing (Traefik)

Because the origin is `https://…`, cloudflared connects to Traefik's **existing** `:443`
`websecure` entrypoint (wildcard LE cert terminates TLS; SNI = the hostname; Host header
routes to the right backend). No port-80 redirect loop because we never use the redirecting
`web` (80) entrypoint. **No new Traefik entrypoint and no `traefik.yaml` change** — confirm with
`tofu plan`/`portainer apply`.

- cloudflared validates Traefik's cert against public CAs (Let's Encrypt wildcard is
  publicly trusted) — no `noTlsVerify`.
- Ensure cloudflared cannot be reached as a public route itself (it listens only outbound;
  it has no exposed `http://` entry), so the only path to Traefik for these hosts is via
  the tunnel connector.

## Files changed

- `terraform/cloudflare/variables.tf` — add 3 `tunnel_apps`.
- `terraform/cloudflare/main.tf` — add 3 access applications; wire ingress rules.
- `stacks/cloudflared/compose.yaml` — join `proxy` network.

## Operational verification

1. `make check` (validate + fmt) in `terraform/cloudflare/`.
2. `make plan` — expect: 3 new tunnel ingress routes, 3 new CNAME records, 3 new Access
   apps (and no destruction). Review the diff.
3. `tofu apply`, then `make apply` in `terraform/portainer/` (applies stacks changes,
   incl. cloudflared network join + Traefik).
4. Restart `cloudflared` (pick up tunnel config) and `traefik` if the entrypoint changed.
5. Verify from a device NOT on the VPN (public DNS): `n8n`, `auth`, `hass` resolve via the
   tunnel and serve over HTTPS with no redirect loop.

## Acknowledged unknowns

- Exact TF schema for `cloudflare_zero_trust_access_application` + `origin_request.access`
  in the pinned provider 5.22.0 hash-style block format is verified during `make plan`;
  adjust as needed.
- Whether `origin_request.access` is needed depends on whether we gate on CFI JWT. If we
  include it, the Access app `aud_tag` must match. Decide + set before apply.
- DNS change is live (public CNAME for these hosts moves to the tunnel edge). Authentik
  (`auth`) is the IdP; if the tunnel/CF has an outage, SSO via Cloudflare path is down.
  Internal/VPN access is not affected (split DNS).
