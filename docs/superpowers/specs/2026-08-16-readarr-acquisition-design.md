# Readarr + rreading-glasses (book acquisition) — Design (2026-08-16)

## Context

- The calibre stack is fully automated: CWA (`calibre-web-automated` v4.0.6) is the **single writer** of the shared `metadata.db` (NAS `books/library`): it ingests from a staging folder → metadata (LubimyCzytac first for PL) → DeDRM → kepub → Kobo sync (`/kobo`), all reproducible from the repo (`make calibre-restore`). Desktop GUI (`calibre-gui.dominiksiejak.pl`) curates the same library.
- The user wants an *acquisition* path: search / request / download books automatically. Readarr is the obvious Sonarr-for-books manager, but the official Readarr was **archived June 2025**.
- `blampe/rreading-glasses` (Go, 1.5k★) is **not** a book manager — it is a drop-in replacement for Readarr's defunct **GoodReads** metadata service. It serves the `GetWork/GetAuthor/GetBook` API that Readarr's metadata client consumes. ~12k daily users of the shared hosted instance; fully self-hostable with a Postgres key/value backend.
- Mediabox stack already runs the whole download/indexer/VPN layer: `gluetun` (NordVPN WireGuard), `qbittorrent`, `sabnzbd` (both VPN-routed), `prowlarr` (indexers), `flaresolverr`, plus `radarr`/`sonarr`/`bazarr`/`jellyfin`/`seerr`/`profilarr`/`scraparr`. Pinning/authoring a `readarr` service follows the existing radarr/sonarr pattern exactly.
- CWA supports exactly **one** ingest folder (`/app/calibre-web-automated/dirs.json`, hardcoded `DIRS_JSON` path, no env override). Manual-drop folder today is NAS `books/inbox`.

## Decisions (with user)

- **Readarr downloads → CWA ingests** (CWA stays sole writer of `metadata.db`).
- **Fork**: `faustvii/readarr` (classic Readarr name/UI fork that works with rreading-glasses).
- **Metadata backend**: self-hosted `blampe/rreading-glasses` (goodreads upstream), backed by the repo's centralized Postgres — no third-party metadata traffic.
- **Staging wiring**: Readarr = primary book source; **CWA's ingest mount repointed** from `books/inbox` → `books/bookarr`. Manual drops move to a dedicated `books/drop` folder consumed by the GUI auto-add folder.
- rreading-glasses v0.9.1 readarr: Readarr's Settings → Metadata Provider Source points at the self-hosted rreading-glasses service.
- Auth/routing consistent with other `*arr` tools: `readarr.dominiksiejak.pl` behind `remote@file` (not Authentik).

## Goal

Search and request a book in Readarr → it's downloaded (VPN-routed, via prowlarr-selected indexer) into `books/bookarr` → CWA auto-imports it with metadata (LubimyCzytac/PL-first), DeDRM-strips when possible, converts to KEPUB → appears in the shared library and syncs to the Kobo. Zero manual steps after one-time setup. All reproducible from the repo.

## Architecture (after change)

```
                       mediabox (gluetun VPN)                        calibre stack
┌─────────────────────────────────────────────────────────┐   ┌──────────────────────────┐
│ gluetun → qbittorrent, sabnzbd (vpn-routed)             │   │ CWA (sole writer)         │
│ prowlarr (indexers)                                     │   │   books/bookarr →         │
│ readarr (faustvii) ──┬── root folder: books/bookarr     │   │   /cwa-book-ingest       │
│   on arr,proxy,database└── metadata provider ─►         │   │   → metadata (LubimyCzytac│
│ rreading-glasses (blampe image, goodreads) ◄────────────┘   │   → DeDRM → kepub         │
│   Postgres: centralized bookarr_db (database network)        │   → metadata.db → /kobo  │
└─────────────────────────────────────────────────────────┘   └──────────────────────────┘
         books/bookarr (NAS) = shared staging root; books/library = single metadata.db
```

- **Readarr** runs in mediabox, VPN-adjacent (reaches qbit/sab via gluetun), indexers from prowlarr (Add Application makes Readarr a prowlarr app), root folder `books/bookarr`. It does **not** import or rename into the calibre library — CWA does.
- **rreading-glasses** runs in mediabox, provides GoodReads metadata to Readarr, persists to the centralized Postgres `bookarr_db`.
- **CWA ingest mount repointed**: calibre compose `books/bookarr` → `/cwa-book-ingest`. Manual drops: `books/drop` mounted to the GUI container and set as its watched auto-add folder.
- CWA remains sole writer; Readarr's own "library" view is search-only (its root folder stays populated-then-cleared by CWA).

## Components

### 1. Readarr service (mediabox)

- `stacks/mediabox/compose.yaml` add `readarr`:
  - image `ghcr.io/faustvii/readarr:0.9.1` (confirmed GHCR package, tags 0.9.0/0.9.1; the archived `Readarr/Readarr` is dead)
  - `<<: *service-defaults` (networks `proxy, arr`), `env_file` none (manual config like radarr/sonarr)
  - `depends_on` qbittorrent, sabnzbd, prowlarr healthy
  - volumes: `readarr_config:/config`, `/mnt/LOCAL_MEDIA:/mnt/LOCAL_MEDIA`, `/mnt/NAS_Shared_Media:/mnt/NAS_Shared_Media`
  - networks override → `network_mode: service:gluetun` is NOT wanted here (Readarr itself doesn't need VPN for downloads; keep `proxy, arr`). Downloads go to qbit/sab which are gluetun-routed. *(Decision: match radarr's non-glutun networks: radarr runs on `proxy,arr`. Keep readarr on `proxy,arr` + add `database` so it can reach rreading-glasses.*)
  - labels: Traefik router `readarr` → `readarr.dominiksiejak.pl`, middleware `remote@file`, port 8787
  - healthcheck: `curl -f http://localhost:8787/`
- Readarr connects to: qbittorrent + sabnzbd (download clients), prowlarr (indexer apps sync), rreading-glasses (Metadata Provider Source).

### 2. rreading-glasses service (mediabox)

- `stacks/mediabox/compose.yaml` add `rreading-glasses`:
  - image `blampe/rreading-glasses:latest`
  - entrypoint `["/main","serve"]`, args `--upstream=www.goodreads.com --verbose`
  - `mem_limit: 128m`
  - environment `POSTGRES_HOST`, `POSTGRES_DATABASE`, `POSTGRES_USER`, `POSTGRES_PASSWORD` (from Vault via repo-provided env, matching `database` network pattern used by n8n)
  - networks: `database` (+ `proxy, arr` per service-defaults anchor; override to just `database, arr`)
  - expose port 8788 internally; **no host port**
- Readarr accesses it at `http://rreading-glasses:8788` (readarr joins `database` network).

### 3. Postgres provisioning (terraform)

- Add `bookarr` to `terraform/postgres/locals.tf` `databases`: username `rreading_glasses`, database `bookarr_db`.
- Add matching entry to `terraform/vault/locals.tf` (password from Vault).
- Run `make apply` in `terraform/postgres` (uses `POSTGRES_SSH_TARGET` tunnel) then `terraform/vault`.
- `.env` for mediabox carries `RRG_PG_USER/PG_PASSWORD/PG_DB` (gitignored `.env` committed pattern with `.env.example`).

### 4. CWA ingest repoint + manual drop folder

- `stacks/calibre/compose.yaml` CWA volume: `/mnt/NAS_Shared_Media/books/bookarr:/cwa-book-ingest` (was `books/inbox`).
- `stacks/calibre/compose.yaml` GUI calibre: add `/mnt/NAS_Shared_Media/books/drop:/mnt/NAS_Shared_Media/books/drop`; set GUI auto-add watched folder to `books/drop` (seeded via `gui-global.py.json` → calibre's auto-add-folder setting is stored in GUI prefs, applied via `make calibre-seed`).
- `books/inbox` retired from ingest (kept dir or removed).

## Data flow

1. User searches/requests book in `readarr` UI → metadata from rreading-glasses (GoodReads) → selects edition/indexer.
2. Readarr sends to qbittorrent or sabnzbd (gluetun-routed) → file written into `books/bookarr`.
3. CWA polls `/cwa-book-ingest` (= `books/bookarr`) → imports; source kept byte-identical; original archived to `/config/processed_books`.
4. Metadata enrichment with `lubimyczytac` first (PL), google/other fallback (PL/EN/ES).
5. DeDRM strips Adept (v10 plugin in active config + ADE key, seeded `dedrm.json`).
6. Convert: normalized epub + KEPUB for Kobo.
7. Book live in shared library (CWA UI + GUI); Kobo wifi syncs via `/kobo` over Tailscale.
8. CWA removes ingested files from `bookarr`, so Readarr's root stays clean; Readarr "unmapped" is expected/normal.

## Error handling / ops

- Readarr queue shows download failures with reasons (indexer/dnldr); prowlarr sync logs.
- CWA per-book ingest status (processed / failed-with-reason); processed backups in `/config/processed_books`.
- rreading-glasses: Postgres KV backend; restart-safe; `mem_limit` prevents OOM; failures surface in Readarr's metadata search as empty results.
- Traefik labels auto-reload on container events.
- Rollback: revert calibre compose mounts, `make apply` terraform/portainer; NAS dirs and library untouched.

## Security

- Readarr exposed on `remote@file` (same as radarr/sonarr); Authentik not added.
- No new secrets committed; DB password lives in Vault → `.env` (gitignored) → env var.
- rreading-glasses reachable only on internal docker networks (`arr`,`database`); no host/public port.
- DeDRM/ADE key handling unchanged (seeded `dedrm.json`, user-supplied key stays on host).

## Out of scope (non-goals)

- Hardcover metadata source for rreading-glasses (`-hardcover` tag needs API token that expires annually) — goodreads default only.
- Authentik auth for readarr (future nicety).
- Readarr managing its own calibre library or renaming into `books/library`.
- Email/notification automation for new books.
- Adding readarr to homepage tile now (deferred with gatus).

## Verification (acceptance)

- A1: Readarr UI loads at `readarr.dominiksiejak.pl`, search returns GoodReads results (via self-hosted rreading-glasses).
- A2: Request a DRM-free book in Readarr → downloads → appears in `books/bookarr` → CWA imports it into shared library with metadata + kepub within a few minutes.
- A3: Existing manual-drop folder `books/drop` → GUI auto-add still ingests.
- A4: `/kobo` sync still responds; books reach Kobo over Tailscale.
- A5: `make calibre-seed` idempotent re-run leaves GUI/CWA config in desired state (incl. new auto-add folder).

## Deployment steps

1. Postgres: add `bookarr` to terraform locals (postgres + vault), apply both, wire `.env` vars.
2. Mediabox compose: add `readarr` + `rreading-glasses` services.
3. Calibre compose: repoint CWA ingest to `books/bookarr`; mount `books/drop` on GUI; seed GUI auto-add folder.
4. Run `make apply` in `terraform/portainer` (syncs stacks → applies mediabox + calibre).
5. Readarr first-run config: root folder `/mnt/NAS_Shared_Media/books/bookarr`, download clients (qbit+sab), prowlarr app sync, metadata source `http://rreading-glasses:8788`.
6. GUI Preferences → auto-add `books/drop` (seed via `make calibre-seed`).
7. Acceptance A1–A5.
8. `README.md` changelog `### 16.08.2026`.

## Testing notes

- Readarr config is manual-in-UI on first run (like radarr/sonarr); document steps; add to restore README.
- rreading-glasses is stateless-ish (Postgres KV): `calibre-restore` doesn't need to cover it beyond compose + env.
- CWA ingest path change via compose is covered by existing `make apply` flow.