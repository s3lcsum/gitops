# *arr web UIs behind Authentik with /api bypass — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gate the web UIs of Sonarr, Radarr, Prowlarr, and Bazarr with Authentik SSO while leaving `/api/*` reachable without auth so existing API-key clients keep working.

**Architecture:** Two Traefik routers per service on the same host. The high-priority `<svc>-api` router matches `PathPrefix(/api)` with no middleware. The default `<svc>` router catches the rest and attaches `authentik@docker` forwardauth. Both routers share one backend service. No middleware changes; Authentik UI gets a Proxy Provider + Application per app, bound to the existing embedded outpost.

**Tech Stack:** Docker Compose, Traefik v3 (labels), Authentik (admin UI), existing CrowdSec middleware.

**Spec:** `docs/superpowers/specs/2026-05-18-arr-authentik-api-bypass-design.md`

---

## Chunk 1: Compose label changes

### Task 1: Sonarr labels — dual-router split

**Files:**
- Modify: `stacks/mediabox/compose.yaml` (sonarr service, lines ~152-156)

- [ ] **Step 1: Read current sonarr labels block**

Confirm current shape before editing:

```bash
sed -n '137,160p' stacks/mediabox/compose.yaml
```

Expected: existing labels block with single `traefik.http.routers.sonarr.rule` plus commented-out `middlewares: authentik@docker` line.

- [ ] **Step 2: Replace sonarr labels with two-router shape**

Replace the existing labels block under `sonarr:` with:

```yaml
    labels:
      traefik.enable: true
      traefik.docker.network: proxy
      traefik.http.services.sonarr.loadbalancer.server.port: 8989

      # API: bypass Authentik, sonarr enforces X-Api-Key
      traefik.http.routers.sonarr-api.rule: (Host(`sonarr.hello.dominiksiejak.pl`) || Host(`sonarr.lake.dominiksiejak.pl`)) && PathPrefix(`/api`)
      traefik.http.routers.sonarr-api.service: sonarr
      traefik.http.routers.sonarr-api.priority: 100

      # Web UI: behind Authentik SSO
      traefik.http.routers.sonarr.rule: Host(`sonarr.hello.dominiksiejak.pl`) || Host(`sonarr.lake.dominiksiejak.pl`)
      traefik.http.routers.sonarr.service: sonarr
      traefik.http.routers.sonarr.middlewares: authentik@docker
      traefik.http.routers.sonarr.priority: 10
```

Notes:
- Keep `traefik.docker.network: proxy` even if other services in the file don't set it explicitly — it's harmless and matches the `seerr` pattern already in this file.
- Do NOT remove the `# traefik.http.routers.sonarr.middlewares: authentik@docker` legacy comment — it's been replaced with a real label now, so delete that commented line.

- [ ] **Step 3: Validate compose syntax**

```bash
docker compose -f stacks/mediabox/compose.yaml config --quiet
```

Expected: exit 0, no output. If parse error, fix YAML indentation.

- [ ] **Step 4: Commit**

```bash
git add stacks/mediabox/compose.yaml
git commit -m "feat(mediabox): split sonarr into api/web routers, authentik on UI"
```

---

### Task 2: Radarr labels — dual-router split

**Files:**
- Modify: `stacks/mediabox/compose.yaml` (radarr service, lines ~127-131)

- [ ] **Step 1: Replace radarr labels**

Same pattern as Task 1. Replace radarr's labels block with:

```yaml
    labels:
      traefik.enable: true
      traefik.docker.network: proxy
      traefik.http.services.radarr.loadbalancer.server.port: 7878

      # API: bypass Authentik, radarr enforces X-Api-Key
      traefik.http.routers.radarr-api.rule: (Host(`radarr.hello.dominiksiejak.pl`) || Host(`radarr.lake.dominiksiejak.pl`)) && PathPrefix(`/api`)
      traefik.http.routers.radarr-api.service: radarr
      traefik.http.routers.radarr-api.priority: 100

      # Web UI: behind Authentik SSO
      traefik.http.routers.radarr.rule: Host(`radarr.hello.dominiksiejak.pl`) || Host(`radarr.lake.dominiksiejak.pl`)
      traefik.http.routers.radarr.service: radarr
      traefik.http.routers.radarr.middlewares: authentik@docker
      traefik.http.routers.radarr.priority: 10
```

Delete the legacy `# traefik.http.routers.radarr.middlewares: authentik@docker` comment.

- [ ] **Step 2: Validate**

```bash
docker compose -f stacks/mediabox/compose.yaml config --quiet
```

- [ ] **Step 3: Commit**

```bash
git add stacks/mediabox/compose.yaml
git commit -m "feat(mediabox): split radarr into api/web routers, authentik on UI"
```

---

### Task 3: Prowlarr labels — dual-router split

**Files:**
- Modify: `stacks/mediabox/compose.yaml` (prowlarr service, lines ~103-106)

- [ ] **Step 1: Replace prowlarr labels**

```yaml
    labels:
      traefik.enable: true
      traefik.docker.network: proxy
      traefik.http.services.prowlarr.loadbalancer.server.port: 9696

      # API: bypass Authentik, prowlarr enforces X-Api-Key
      traefik.http.routers.prowlarr-api.rule: (Host(`prowlarr.hello.dominiksiejak.pl`) || Host(`prowlarr.lake.dominiksiejak.pl`)) && PathPrefix(`/api`)
      traefik.http.routers.prowlarr-api.service: prowlarr
      traefik.http.routers.prowlarr-api.priority: 100

      # Web UI: behind Authentik SSO
      traefik.http.routers.prowlarr.rule: Host(`prowlarr.hello.dominiksiejak.pl`) || Host(`prowlarr.lake.dominiksiejak.pl`)
      traefik.http.routers.prowlarr.service: prowlarr
      traefik.http.routers.prowlarr.middlewares: authentik@docker
      traefik.http.routers.prowlarr.priority: 10
```

- [ ] **Step 2: Validate**

```bash
docker compose -f stacks/mediabox/compose.yaml config --quiet
```

- [ ] **Step 3: Commit**

```bash
git add stacks/mediabox/compose.yaml
git commit -m "feat(mediabox): split prowlarr into api/web routers, authentik on UI"
```

---

### Task 4: Bazarr labels — dual-router split

**Files:**
- Modify: `stacks/mediabox/compose.yaml` (bazarr service, lines ~171-174)

- [ ] **Step 1: Replace bazarr labels**

```yaml
    labels:
      traefik.enable: true
      traefik.docker.network: proxy
      traefik.http.services.bazarr.loadbalancer.server.port: 6767

      # API: bypass Authentik, bazarr enforces X-Api-Key
      traefik.http.routers.bazarr-api.rule: (Host(`bazarr.hello.dominiksiejak.pl`) || Host(`bazarr.lake.dominiksiejak.pl`)) && PathPrefix(`/api`)
      traefik.http.routers.bazarr-api.service: bazarr
      traefik.http.routers.bazarr-api.priority: 100

      # Web UI: behind Authentik SSO
      traefik.http.routers.bazarr.rule: Host(`bazarr.hello.dominiksiejak.pl`) || Host(`bazarr.lake.dominiksiejak.pl`)
      traefik.http.routers.bazarr.service: bazarr
      traefik.http.routers.bazarr.middlewares: authentik@docker
      traefik.http.routers.bazarr.priority: 10
```

- [ ] **Step 2: Validate**

```bash
docker compose -f stacks/mediabox/compose.yaml config --quiet
```

- [ ] **Step 3: Commit**

```bash
git add stacks/mediabox/compose.yaml
git commit -m "feat(mediabox): split bazarr into api/web routers, authentik on UI"
```

---

## Chunk 2: Authentik UI configuration (manual)

These steps run in the Authentik admin UI at `https://auth.lake.dominiksiejak.pl/if/admin/`. Repeat the block for each of the four apps. No file changes; document the result in a runbook comment if desired.

### Task 5: Create Proxy Provider + Application for each *arr

For **each** of `sonarr`, `radarr`, `prowlarr`, `bazarr`:

- [ ] **Step 1: Create Proxy Provider**

  Admin UI → *Applications* → *Providers* → *Create* → **Proxy Provider**.
  - Name: `<svc>-proxy` (e.g. `sonarr-proxy`)
  - Authorization flow: existing default authorization flow (the one already used by other Authentik-protected apps in this homelab — pick from dropdown, don't create new)
  - Mode: **Forward auth (single application)**
  - External host: `https://<svc>.lake.dominiksiejak.pl`
  - Leave everything else default; save.

- [ ] **Step 2: Create Application**

  Admin UI → *Applications* → *Applications* → *Create*.
  - Name: capitalized service name (e.g. `Sonarr`)
  - Slug: `<svc>` (lowercase)
  - Provider: select `<svc>-proxy` from step 1
  - Save.

- [ ] **Step 3: Bind to embedded outpost**

  Admin UI → *Applications* → *Outposts* → click **embedded outpost** → *Edit*.
  - In the *Applications* / providers list, ensure the new `<svc>-proxy` provider is selected.
  - Save. The outpost auto-reloads.

- [ ] **Step 4: Smoke-test that one service**

  After completing steps 1-3 for that service, run the verification block in Task 6 for that hostname before moving to the next service. This catches misconfig early instead of after all four.

---

## Chunk 3: Deploy and verify

### Task 6: Deploy and verify all four services

- [ ] **Step 1: Pull and recreate the mediabox stack**

  On the docker host (via Portainer redeploy, or SSH):

  ```bash
  cd /opt/mediabox  # or wherever the stack lives on the host
  docker compose pull
  docker compose up -d
  ```

  Or trigger the Portainer "Pull & Redeploy" for the `mediabox` stack.

- [ ] **Step 2: Confirm Traefik picked up new routers**

  ```bash
  docker logs traefik 2>&1 | tail -50 | grep -iE 'router|sonarr|radarr|prowlarr|bazarr'
  ```

  Expected: no error lines about routers; routers `sonarr@docker`, `sonarr-api@docker`, etc. visible.

  Alternative: open Traefik dashboard at `https://traefik.lake.dominiksiejak.pl/dashboard/#/http/routers` — confirm 8 new entries (two per service), all `enabled`.

- [ ] **Step 3: Verify /api bypass for each service**

  Run from a host with an API key handy (replace `<key>`):

  ```bash
  curl -fsS -H 'X-Api-Key: <key>' https://sonarr.lake.dominiksiejak.pl/api/v3/system/status -o /dev/null -w '%{http_code}\n'
  curl -fsS -H 'X-Api-Key: <key>' https://radarr.lake.dominiksiejak.pl/api/v3/system/status -o /dev/null -w '%{http_code}\n'
  curl -fsS -H 'X-Api-Key: <key>' https://prowlarr.lake.dominiksiejak.pl/api/v1/system/status -o /dev/null -w '%{http_code}\n'
  curl -fsS -H 'X-Api-Key: <key>' https://bazarr.lake.dominiksiejak.pl/api/system/status -o /dev/null -w '%{http_code}\n'
  ```

  Expected: `200` for each. If any returns `302` to `/outpost.goauthentik.io/...`, the router rule didn't match — check priority and `PathPrefix` syntax.

- [ ] **Step 4: Verify /api without key returns 401 (not redirect)**

  ```bash
  curl -sS -o /dev/null -w '%{http_code}\n' https://sonarr.lake.dominiksiejak.pl/api/v3/system/status
  ```

  Expected: `401` (from Sonarr). If `302`, Authentik is intercepting `/api` — fix router rule. Repeat for the other three.

- [ ] **Step 5: Verify web UI redirects to Authentik**

  In a browser, visit `https://sonarr.lake.dominiksiejak.pl/`.
  Expected: redirect to `auth.lake.dominiksiejak.pl`, login, then return to Sonarr UI logged in. Repeat for radarr/prowlarr/bazarr.

- [ ] **Step 6: Verify Prowlarr → *arr sync still works**

  Prowlarr UI → *Settings* → *Apps* → click each *arr → *Test*.
  Expected: green "Test was successful". This confirms Prowlarr's outbound `/api/v3/...` calls bypass Authentik correctly.

- [ ] **Step 7: Verify Bazarr ↔ Sonarr/Radarr**

  Bazarr UI → *Settings* → *Sonarr* → *Test*. Same for *Radarr*.
  Expected: green checkmark. (Note: if Bazarr is configured to talk to internal container DNS like `http://sonarr:8989`, it's unaffected by Traefik changes — but verify anyway.)

- [ ] **Step 8: Final commit (if any tweaks were needed)**

  If steps 3-7 required label adjustments, commit them now. Otherwise, the four commits from Chunk 1 are the entire change.

---

## Rollback

If anything breaks after deploy, revert in one shot:

```bash
git revert <task1-sha>..<task4-sha>
# or: git reset --hard <sha-before-task-1> && force-push if not yet pushed
```

Then redeploy the stack. Authentik UI config can stay — orphaned providers don't break anything; delete them via the UI if desired.

---

## Notes for the implementer

- Each service is one focused commit. If you need to revert just Bazarr (say), the per-service commits make that trivial.
- Don't add the same pattern to `qbittorrent`, `sabnzbd`, `jellyfin`, or `seerr` in this change — out of scope, different auth models.
- The `authentik@docker` middleware name comes from labels on the `authentik-server` container in `stacks/authentik/compose.yaml`. Don't redefine it.
- CrowdSec sits in front of everything via the entrypoint middleware chain — no change needed; both new routers inherit it automatically.
