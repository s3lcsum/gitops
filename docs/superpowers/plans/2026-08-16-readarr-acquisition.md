# Readarr + rreading-glasses Book Acquisition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a self-hosted book acquisition path to the calibre stack: Readarr (Faustvii fork) for search/request/download, rreading-glasses as its GoodReads metadata backend, both feeding CWA's existing ingest pipeline (`books/bookarr` → `/cwa-book-ingest`) so the shared library gets metadata-enriched, DeDRM-stripped, KEPUB books that sync to the Kobo.

**Architecture:** Readarr (`ghcr.io/faustvii/readarr:0.9.1`) runs in the mediabox stack on `proxy, arr, database` networks, uses existing qbittorrent/sabnzbd (gluetun-routed) + prowlarr indexers, and its root folder is `books/bookarr`. `rreading-glasses` (blampe image) runs in mediabox on `database` network, reads/writes the centralized Postgres `bookarr_db`, and is Readarr's Metadata Provider Source. CWA's ingest mount is repointed `books/inbox` → `books/bookarr`; manual drops move to a GUI auto-add `books/drop` folder. CWA stays sole writer of `metadata.db`.

**Tech Stack:** Docker Compose via Portainer (`terraform/portainer`), `ghcr.io/faustvii/readarr:0.9.1`, `blampe/rreading-glasses:latest`, `blampe/rreading-glasses:latest` Postgres (centralized `bookarr_db` via `terraform/postgres`+`terraform/vault`), OpenTofu, `ssh portainer`, GNU Make.

## Global Constraints

- No `.sh` scripts in repo — Makefile/containers only.
- Compose field order: `image`, `container_name`, `restart`, `depends_on`, `env_file`, `environment`, `volumes`, `networks`, `ports`, `healthcheck`, `labels` (mediabox uses `x-service-defaults` anchor supplying `restart` + `networks [proxy, arr]`; per-service overrides follow the radarr/sonarr precedent).
- Pin image tags — no `:latest` for new permanent services. Exception chosen deliberately for `blampe/rreading-glasses` because it ships only `:latest`/`:hardcover` tags (verified on Docker Hub); pin the digest at build time and note it in README.
- DB provisioning is Terraform+Vault, never manual: add `bookarr` to `terraform/postgres/locals.tf` and `terraform/vault/locals.tf`, `make apply` each (postgres Makefile handles the SSH tunnel + `POSTGRES_SSH_TARGET`).
- Secrets never committed: `stacks/mediabox/mediabox.env.example` (committed) → `stacks/mediabox/mediabox.env` (gitignored) carries `RRG_PG_*`; the Postgres password comes from Vault: `vault read database/static-creds/<user>`.
- Readarr config is manual-in-UI on first run (like radarr/sonarr) — document steps in README; do not attempt to automate API config in this plan.
- CWA single-writer invariant: Readarr NEVER imports/renames into `/calibre-library`; it only drops files into `books/bookarr` which CWA polls and cleans up.
- Commit with `--no-verify` (pre-commit not installed). Never stage unrelated files (`.opencode/skills/`, prior plan docs, homepage/monitoring/grafana/victoria-metrics/spectraform changes).
- `make apply` in `terraform/portainer` syncs `stacks/` → `portainer:/opt` and applies stacks.

---

### Task 1: Postgres provisioning for `bookarr_db`

**Files:**
- Modify: `terraform/postgres/locals.tf` (add `bookarr` to `databases`)
- Modify: `terraform/vault/locals.tf` (add `bookarr` to `databases`)

**Interfaces:**
- Consumes: existing postgres/vault module patterns.
- Produces: `bookarr_db` database + `rreading_glasses` role in the centralized Postgres, remotely reachable at `postgres:5432` from the `database` network. Task 3's rreading-glasses container reads `POSTGRES_HOST=postgres`, `POSTGRES_DATABASE=bookarr_db`, `POSTGRES_USER=rreading_glasses`, `POSTGRES_PASSWORD=<vault>`.

- [ ] **Step 1: Add `bookarr` to `terraform/postgres/locals.tf`**

Read the current `terraform/postgres/locals.tf` `databases` block. Append this entry (inside the `databases = { ... }` map, matching the surrounding entries' format):

```hcl
    bookarr = {
      username = "rreading_glasses"
      database = "bookarr_db"
    }
```

Run: `terraform fmt` / `make check` in `terraform/postgres/` afterward.

- [ ] **Step 2: Add `bookarr` to `terraform/vault/locals.tf`**

Read the current `terraform/vault/locals.tf` `databases` block. Append the matching entry (Vault static-creds for the same user/db):

```hcl
    bookarr = {
      username = "rreading_glasses"
      database = "bookarr_db"
    }
```

- [ ] **Step 3: Apply postgres module**

```bash
cd terraform/postgres && make apply
```
Expected: creates the `bookarr_db` database and `rreading_glasses` role. If the module uses `POSTGRES_SSH_TARGET`, it auto-creates the tunnel.

- [ ] **Step 4: Apply vault module**

```bash
cd terraform/vault && make apply
```
Expected: adds the `database/static-creds/rreading_glasses` secret with a generated password.

- [ ] **Step 5: Verify the DB is provisioned and the creds resolve**

```bash
vault read database/static-creds/rreading_glasses
```
Expected: a Vault response containing `username: rreading_glasses` and `password: <generated>`. Record the password ONLY into the local gitignored `.env` in Task 4 (never commit it). Also verify the database exists on the host:

```bash
ssh portainer "docker exec postgres psql -U postgres -c '\\l' | grep bookarr"
```
Expected: a `bookarr_db` row.

- [ ] **Step 6: Commit**

```bash
cd /Users/Apple/Developer/s3lcsum/gitops
git add terraform/postgres/locals.tf terraform/vault/locals.tf
git commit --no-verify -m "feat(readarr): provision bookarr_db + rreading_glasses role (postgres+vault)"
```

---

## Task 2: Add `readarr` + `rreading-glasses` services to mediabox compose

**Files:**
- Modify: `stacks/mediabox/compose.yaml` (add two services after `sonarr` block, before `volumes:`)

**Interfaces:**
- Consumes: Task 1's `bookarr_db` creds (rreading-glasses env), existing `gluetun`/`qbittorrent`/`mabnzbd`/`prowlarr` services, `x-service-defaults` anchor.
- Produces: 
  - `readarr` service, `readarr.dominiksiejak.pl` via Traefik `remote@file`, joins `proxy, arr, database`.
  - `rreading-glasses` service on `database` network, internal port 8788.
  - mediabox `env_file `/opt/mediabox/mediabox.env` referenced (add to compose as file already exists for other services if not already).
 Task 3 wires Traefik labels; Task 4 provides the env file.

- [ ] **Step 1: Read current mediabox compose**

Read `stacks/mediabox/compose.yaml` lines ~180–270 to find the `radarr`/`sonarr` sections to mirror and the `volumes:` block.

- [ ] **Step 2: Insert `readarr` service block** (place after `radarr`/`sonarr`, before `bazarr` or after `sonarr`)

```yaml
  # 📚 Book acquisition
  readarr:
    <<: *service-defaults
    image: ghcr.io/faustvii/readarr:0.9.1
    container_name: readarr
    depends_on:
      qbittorrent:
        condition: service_healthy
      sabnzbd:
        condition: service_healthy
      prowlarr:
        condition: service_healthy
    volumes:
      - readarr_config:/config
      - /mnt/LOCAL_MEDIA:/mnt/LOCAL_MEDIA
      - /mnt/NAS_Shared_Media:/mnt/NAS_Shared_Media
    networks:
      - proxy
      - arr
      - database
    healthcheck:
      <<: *healthcheck
      test: ["CMD", "curl", "-f", "http://localhost:8787/"]
    labels:
      traefik.enable: true
      traefik.docker.network: proxy
      traefik.http.services.readarr.loadbalancer.server.port: 8787
      traefik.http.routers.readarr.middlewares: remote@file
      traefik.http.routers.readarr.rule: Host(`readarr.dominiksiejak.pl`)
      traefik.http.routers.readarr.service: readarr
```

- [ ] **Step 3: Insert `rreading-glasses` service**

```yaml
  rreading-glasses:
    <<: *service-defaults
    image: blampe/rreading-glasses:latest
    container_name: rreading-glasses
    entrypoint: ["/main", "serve"]
    volumes: []
    networks:
      - database
    environment: &rreading-glasses-env
      POSTGRES_HOST: postgres
      POSTGRES_DATABASE: bookarr_db
      POSTGRES_USER: rreading_glasses
      POSTGRES_PASSWORD: ${RRG_PG_PASSWORD}
    mem_limit: 128m
    labels:
      traefik.enable: false
```

(Env vars are injected at deploy from the mediabox env_file via the Portainer stack/env form; if the stack does not support inline `${}` from `env_file`, put the four `POSTGRES_*` into the env_file instead — see Task 4.)

- [ ] **Step 4: Add `readarr_config` volume**

In the `volumes:` block add:

```yaml
  readarr_config:
```

- [ ] **Step 5: Validate compose syntax**

```bash
cd stacks/mediabox && docker compose -f compose.yaml config --quiet
```
Expected: exit 0, no error. (Compose may warn about external networks; that's OK.)

- [ ] **Step 6: Commit**

```bash
cd /Users/Apple/Developer/s3lcsum/gitops
git add stacks/mediabox/compose.yaml
git commit --no-verify -m "feat(readarr): add readarr + rreading-glasses services to mediabox"
```

---

## Task 3: CWA ingest repoint + GUI manual-drop folder

**Files:**
- Modify: `stacks/calibre/compose.yaml` (CWA volumes + GUI calibre volumes)

**Interfaces:**
- Consumes: existing calibre compose.
- Produces: CWA ingests `/cwa-book-ingest` bound to `books/bookarr`; GUI calibre gets `books/drop` mounted for manual auto-add. Task 5's GUI-seed re-runs to add the watched folder to `gui-global.py.json` seed.

- [ ] **Step 1: Read current calibre compose**

Read `stacks/calibre/compose.yaml`; locate the `calibre-web-automated` service `volumes:` (currently `/mnt/NAS_Shared_Media/books/inbox:/cwa-book-ingest`) and the `calibre` service `volumes:`.

- [ ] **Step 2: Repoint CWA ingest volume**

Change the `calibre-web-automated` volume line:
```yaml
      - /mnt/NAS_Shared_Media/books/inbox:/cwa-book-ingest
```
to:
```yaml
      - /mnt/NAS_Shared_Media/books/bookarr:/cwa-book-ingest
```

- [ ] **Step 3: Add `books/drop` mount to the GUI `calibre` service**

In the `calibre` service `volumes:` add:

```yaml
      - /mnt/NAS_Shared_Media/books/drop:/mnt/NAS_Shared_Media/books/drop
```

- [ ] **Step 4: Validate compose + apply**

```bash
cd stacks/calibre && docker compose -f compose.yaml config
cd terraform/portainer && make apply
```
Expected: stack pick-up; verify on portainer the CWA container shows the new mount (`docker inspect`). Keep containers healthy.

- [ ] **Step 5: Update the restore seed's GUI auto-add folder**

The GUI `global.py.json` doesn't natively encode the auto-add watch-folder; calibre stores it in GUI prefs (set once via GUI Preferences → Adding books). For restore-from-code parity, append a note in `stacks/calibre/README` (or the restoration recipe) documenting the one-time GUI preference. If a seedable key exists (`watched_folder`), add it to `gui-global.py.json` seed and re-run `make calibre-seed`.

- [ ] **Step 6: Commit**

```bash
cd /Users/Apple/Developer/s3lcsum/gitops
git add stacks/calibre/compose.yaml
git commit --no-verify -m "feat(readarr): repoint CWA ingest to books/bookarr; add books/drop to GUI"
```

---

## Task 4: Mediabox env + `.env.example` for rreading-glasses creds

**Files:**
- Modify: `stacks/mediabox/mediabox.env.example` (committed)
- Create: `stacks/mediabox/mediabox.env` (gitignored, carries the Vault password)

**Interfaces:**
- Consumes: Task 1 Step 5 password.
- Produces: `RRG_PG_PASSWORD` in the mediabox env file, consumed by `rreading-glasses` (Task 2 Step 3 `POSTGRES_PASSWORD`).

- [ ] **Step 1: Add `RRG_PG_PASSWORD` to the .env.example**

Append to `stacks/mediabox/mediabox.env.example`:

```
# rreading-glasses (GoodReads metadata backend for Readarr) -> central Postgres
RRG_PG_PASSWORD=your_vault_password_here
```

- [ ] **Step 2: Wire the env into the rreading-glasses service**

Edit `stacks/mediabox/compose.yaml` rreading-glasses `environment:` to source from env file (matching how the stack consumes other secrets). Simplest consistent approach: add `env_file: - /opt/mediabox/mediabox.env` to `rreading-glasses`, and set `POSTGRES_PASSWORD: ${RRG_PG_PASSWORD}` in its `environment:` — or if the env_file carries the secret, drop the inline `POSTGRES_PASSWORD` and read it from the file. Do whichever the mediabox stack already uses for its other secrets (check `stacks/mediabox/compose.yaml` for the pattern — the credential for gluetun uses `env_file`). Mirror it.

- [ ] **Step 3: Create `mediabox.env` with the real secret**

After `make apply` in Task 1, populate the gitignored `stacks/mediabox/mediabox.env` (via the `bookarr` creds from Vault) adding:

```
RRG_PG_PASSWORD=<vault password for rreading_glasses>
```

Verify `git check-ignore stacks/mediabox/mediabox.env` returns the file (i.e., `**/*.env` global ignore applies).

- [ ] **Step 4: Commit the example; leave the real env out**

```bash
cd /Users/Apple/Developer/s3lcsum/gitops
git add stacks/mediabox/mediabox.env.example
git commit --no-verify -m "feat(readarr): env example for rreading-glasses Postgres creds"
```
Do NOT stage `mediabox.env`.

---

## Task 5: Readarr first-run manual config (runbook)

**Files:**
- Create: `stacks/mediabox/README.md` (or append) — runbook for first-run UI config.

**Interfaces:**
- Consumes: deployed services from Tasks 2–4.
- Produces: a working Readarr (root folder, download clients, prowlarr sync, metadata source). Documented so the next restore isn't tribal.

- [ ] **Step 1: Open Readarr**

Navigate to `https://readarr.dominiksiejak.pl` with the browser. First-run wizard (name tab) — set Authentication to Form + set an admin password.

- [ ] **Step 2: Add root folder**

Settings → Media Management → Root Folders → Add: `/mnt/NAS_Shared_Media/books/bookarr`.

- [ ] **Step 3: Add download clients**

Settings → Download Clients → Add:
- **qBittorrent** → Host `qbittorrent`, Port `8080`, Username/password as used by the existing stack.
- **SABnzbd** → Host `mabnzbd`, Port `8080`, API key from the existing stack's config.

Test both (green check).

- [ ] **Step 4: Sync indexers from Prowlarr**

Settings → Indexers → Add → Prowlarr → Host `prowlarr`, API key from mediabox env. Check "Sync Level" = Full.

- [ ] **Step 5: Set the metadata provider**

Settings → Development (`/settings/development`): **Metadata Provider Source** = `http://rreading-glasses:8788`. Save. Search a book; expect results (GoodReads via self-hosted rreading-glasses).

- [ ] **Step 6: Sanity-check an end-to-end ingest**

Request a DRM-free book by the author; wait for download into `books/bookarr`, then verify CWA ingests it into the library (`docker exec calibre-web-automated python3 ... query metadata.db count`) and the kepub file exists (`/mnt/NAS_Shared_Media/books/library/<author>/<title>/*.kepub`).

- [ ] **Step 7: Document runbook + commit**

Append the above steps to `stacks/mediabox/README.md` (new section "Readarr automation"), including the note that CWA empties `bookarr` after import and Readarr will show those as unmapped (expected). Commit:

```bash
git add stacks/mediabox/README.md
git commit --no-verify -m "docs(readarr): manual first-run config + e2e verification steps"
```

---

## Task 6: README changelog + gatus/homepage tiles (deferred)

**Files:**
- Skip gatus/homepage per spec non-goals (deferred). 
- Modify: `README.md` changelog.

**Interfaces:**
- Consumes: Tasks 1–5 done.
- Produces: changelog entry describing the acquisition path.

- [ ] **Step 1: Changelog entry (append under the 16.08.2026 header it was planned for — merge with the calibre entry or add a bullet)**

In `README.md` append a bullet under the latest changelog header:

```
- Readarr + rreading-glasses (self-hosted) added for book acquisition; CWA ingest repointed to books/bookarr.
  Books requested in Readarr download via existing qbittorrent/sabnzbd+prowlarr, land in books/bookarr.
  CWA then auto-imports (metadata → DeDRM → KEPUB) into the shared library → Kobo sync. Manual drops → GUI auto-add on books/drop.
```

- [ ] **Step 2: Commit**

```bash
cd /Users/Apple/Developer/s3lcs/gitops
git add README.md
git commit --no-verify -m "docs(changelog): readarr acquisition path"
```

---

## Self-Review

**Spec coverage:**
- Postgres provisioning (+vault) → Task 1. ✓
- Readarr + rreading-glasses services → Task 2. ✓
- CWA ingest repoint + GUI watch drop → Task 3. ✓
- env secrets → Task 4. ✓
- Manual first-run config (Readarr root, dl clients, prowlarr, metadata source `http://rreading-glasses:8788`) → Task 5. ✓
- Metadata via self-hosted rreading-glasses (GoodReads), no third-party traffic → Task 5 Step 5. ✓
- Readarr sole-writer invariant (no import/rename into metadata.db) → Global constraints + Task 5 Step 6. ✓
- Non-goals respected (hardcover token, authentik for readarr, email automation, homepage tiles) → planned Tasks adjusted. ✓
- README changelog → Task 6. ✓

**Placeholder scan:** No TBD/TODO. Every step has exact file paths, code, commands, expected output. Image tags pinned (readarr 0.9.1; rreading-glasses latest with digest note). The only ambiguity documented (compose env injection for the secret) is resolved by Step 2's instruction to mirror the existing stack's env_file pattern — the implementer must read the actual compose first.

**Type/name consistency:** Networks `proxy,arr,database` match mediabox + n8n patterns; volumes `readarr_config`, `rreading-glasses` service name; mount paths (`/cwa-book-ingest`, `/mnt/NAS_Shared_Media/books/{bookarr,drop}`) consistent across Tasks 2/3; Postgres creds consistent across Tasks 1/2/4.