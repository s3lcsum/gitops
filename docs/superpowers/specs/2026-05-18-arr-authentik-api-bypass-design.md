# *arr web UIs behind Authentik with /api bypass

**Date:** 2026-05-18
**Scope:** `stacks/mediabox/compose.yaml` (Sonarr, Radarr, Prowlarr, Bazarr) + Authentik UI config

## Goal

Put the four *arr web UIs behind Authentik SSO (passwordless via the existing default flow) while leaving `/api/*` directly reachable for API-key clients — mobile apps, Prowlarr → *arr sync, Bazarr ↔ Sonarr/Radarr handshakes, ad-hoc curl, etc. The *arr apps themselves already enforce `X-Api-Key` on `/api`, so Traefik just needs to route `/api` past the Authentik forwardauth middleware.

Out of scope: qBittorrent and SABnzbd (own login, query-param API key, plus integration risk with the *arr stack).

## Approach

For each of the four services, replace the current single-router Traefik labels with **two routers on the same host pointing at the same backend service**:

| Router        | Rule                                         | Middleware        | Priority |
| ------------- | -------------------------------------------- | ----------------- | -------- |
| `<svc>-api`   | `Host(...) && PathPrefix(\`/api\`)`          | none              | 100      |
| `<svc>`       | `Host(...)`                                  | `authentik@docker`| 10       |

Traefik routes most-specific-wins; explicit priorities make intent obvious and survive future rule changes. Both routers point at the same `traefik.http.services.<svc>` loadbalancer (same backend port), so only the auth path differs.

## Why path-based (not header-based)

Picked "let *arr handle it natively." The apps return 401 for missing/invalid `X-Api-Key`, so Traefik doesn't need to enforce header presence — keeps the rule small and works for any client hitting `/api`, including SAB-style query-param edge cases the apps already handle internally.

## Per-service label shape

Example for Sonarr; identical shape for Radarr (7878), Prowlarr (9696), Bazarr (6767).

```yaml
labels:
  traefik.enable: true
  traefik.docker.network: proxy
  traefik.http.services.sonarr.loadbalancer.server.port: 8989

  # API: bypass Authentik, *arr enforces X-Api-Key
  traefik.http.routers.sonarr-api.rule: (Host(`sonarr.hello.dominiksiejak.pl`) || Host(`sonarr.lake.dominiksiejak.pl`)) && PathPrefix(`/api`)
  traefik.http.routers.sonarr-api.service: sonarr
  traefik.http.routers.sonarr-api.priority: 100

  # Web UI: behind Authentik SSO
  traefik.http.routers.sonarr.rule: Host(`sonarr.hello.dominiksiejak.pl`) || Host(`sonarr.lake.dominiksiejak.pl`)
  traefik.http.routers.sonarr.service: sonarr
  traefik.http.routers.sonarr.middlewares: authentik@docker
  traefik.http.routers.sonarr.priority: 10
```

The `authentik@docker` middleware already exists on `stacks/authentik/compose.yaml` (forwardauth to `http://authentik-server:9000/outpost.goauthentik.io/auth/traefik`). No middleware changes required.

## Authentik UI work (manual, post-deploy)

For each of the four apps, create in Authentik admin UI:

1. **Proxy Provider** (mode: Forward auth, single application)
   - External host: `https://sonarr.lake.dominiksiejak.pl` (and same for radarr/prowlarr/bazarr)
   - Authorization flow: existing default
2. **Application**
   - Slug: `sonarr` / `radarr` / `prowlarr` / `bazarr`
   - Provider: the proxy provider from step 1
3. Bind each provider to the **embedded outpost** (the one Traefik's `authentik@docker` middleware already talks to).

Reuses existing flow — no passwordless/passkey work needed unless the user later wants to harden these specifically.

## Risks / caveats

- **Internal *arr ↔ *arr calls** (e.g. Bazarr → Sonarr) use container DNS (`http://sonarr:8989`) and bypass Traefik entirely — unaffected.
- **External *arr ↔ *arr calls** through Traefik hostnames hit `/api/*` → routed via `<svc>-api` router → no Authentik. Confirmed working path.
- **RSS feeds / non-`/api` machine endpoints**: anything outside `/api` (e.g. Sonarr's `/feed/...`) **will be gated by Authentik**. If RSS or similar is consumed by external automation, add the path to the bypass router rule (`PathPrefix(\`/api\`) || PathPrefix(\`/feed\`)`). Not adding speculatively.
- **Browser session vs API**: an authenticated browser visiting `/api/...` directly will get the JSON response (Authentik bypass) — this is expected and not a security regression (the API still requires `X-Api-Key`).
- **CrowdSec** middleware on entrypoints stays in front of both routers — no change.

## Files touched

- `stacks/mediabox/compose.yaml` — labels for `radarr`, `sonarr`, `prowlarr`, `bazarr` services.
- No Traefik dynamic config changes.
- No Authentik compose changes (UI config only).

## Verification

- `curl -H 'X-Api-Key: <key>' https://sonarr.lake.dominiksiejak.pl/api/v3/system/status` → 200 JSON, no redirect.
- `curl https://sonarr.lake.dominiksiejak.pl/api/v3/system/status` → 401 from Sonarr (not 302 to Authentik).
- Browser to `https://sonarr.lake.dominiksiejak.pl/` → redirected to Authentik login → after auth, lands in Sonarr UI.
- Repeat for radarr/prowlarr/bazarr.
- Confirm Prowlarr → Sonarr/Radarr sync still works (Settings → Apps in Prowlarr, test connection).
