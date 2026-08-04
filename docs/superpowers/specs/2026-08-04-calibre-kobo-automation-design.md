# Calibre → Kobo Automation — Design (2026-08-04)

## Context

- User has a Kobo reader and wants ebooks stored in the homelab Calibre, synced to Kobo.
- Existing stack (`stacks/calibre/compose.yaml`, deployed via Portainer):
  - `calibre` — linuxserver desktop GUI (noVNC), `calibre-gui.dominiksiejak.pl`, Authentik-protected. Scratch library.
  - `calibre-web` 0.6.26 — `calibre.dominiksiejak.pl`, public (`remote@file` middleware), `calibre-api.dominiksiejak.pl` label also points at it. Book roots `/mnt/LOCAL_MEDIA/books` + `/mnt/NAS_Shared_Media/books` (host paths on Portainer host). `universal-calibre` mod provides `ebook-convert` + `kepubify`.
- Requirements:
  - metadata kept consistent to one standard, automatically
  - strip DRM/security from purchased epubs
  - books in best format for Kobo
  - fully automatic; untouched original copy preserved
  - books live on Kobo automatically
- Sources: "other shops" (Adobe Adept DRM epub) + free downloads (clean, messy metadata). No Amazon/Kindle.
- Decisions made with user:
  - approach A: **calibre-web-automated (CWA)** core + NAS drop-folder ingest
  - n8n and email ingest deferred (future; email reuses the same drop-folder pipeline via n8n IMAP → inbox)
  - no watcher sidecar — the untouched original is preserved in-library as the source format (calibre stores multi-format per book: original epub + converted kepub, byte-identical source)

## Goal

Drop a file on the NAS → within ~1 minute: imported, original preserved, metadata-enriched, DRM-stripped (if Adept), converted to KEPUB, live in library → appears on Kobo after device sync. Zero manual steps after one-time setup.

## Architecture

Services after change in `stacks/calibre/compose.yaml`:

1. `calibre-web-automated` (CWA) — **replaces `calibre-web`**. Image `crocodilestick/calibre-web-automated` (tag pinned at build time). Port :8083. Routers: `calibre.dominiksiejak.pl` (public, `remote@file`) and `calibre-api.dominiksiejak.pl` (OPDS/content). Single writer of the library `metadata.db`. Env: `NETWORK_SHARE_MODE=true`, `TRUSTED_PROXY_COUNT=2`.
2. `calibre` (linuxserver/calibre:9.12.0) — unchanged. Manual GUI fallback; keeps its own scratch library; never opens CWA's `metadata.db`.
3. `calibre-web` — removed. Volume `calibre_web_config` replaced by `cwa_config`.

NAS layout (under `/mnt/NAS_Shared_Media/books/`):

```
books/
├── inbox/    ← CWA ingest folder (`/cwa-book-ingest`); SMB drop target from Mac; files removed after processing
└── library/  ← CWA Calibre library (`/calibre-library`); metadata.db + per-book: original + kepub (auto-created if empty)
```

Untouched originals additionally archived by CWA's built-in backup service to `/config/processed_books` on the `cwa_config` volume (default on; the "separate folder" requirement).

Because the library lives on NFS/SMB: `NETWORK_SHARE_MODE=true` (disables SQLite WAL, switches ingest/metadata watchers to polling). Proxy chain Cloudflare → Traefik → CWA: `TRUSTED_PROXY_COUNT=2`.

## Data flow

1. User drops file into `inbox` (SMB).
2. CWA polls (~30s), imports; source format kept byte-identical in the book record and archived to `/config/processed_books`.
3. Google Books metadata enrichment (title/author/series/cover). No API key for v1; add later if rate-limited.
4. DeDRM: Adept-encrypted epub stripped using uploaded ADE key; clean files pass through untouched.
5. Convert to KEPUB (kepubify bundled in CWA) — Kobo-native format.
6. Book live: web UI + OPDS + Kobo sync endpoint.
7. Kobo wifi sync → book on device.

## Formats (v1)

`epub`, `azw3`, `mobi`, `pdf` — anything calibre can convert.

## Security

- Change CWA admin password on first run (default `admin`/`admin123`); create a limited user for Kobo/OPDS.
- Enable CWA Kobo-sync password.
- Endpoint stays public (Kobo sync + OPDS require it), behind existing `remote@file` middleware. Traefik config unchanged.
- No docker.sock, no scripts, no new secrets in repo.

## Setup-time manual steps (user, one-time)

1. **ADE key**: install Adobe Digital Editions on Mac → log in with Adobe ID → export activation key → upload to CWA Adobe section. This unlocks stripping of Adept-encrypted shop epubs. ~5 minutes.
2. **Kobo linking**: device browser → `https://calibre.dominiksiejak.pl/kobo` → sign in → device linked; thereafter normal Sync pulls new books. Exact menu path verified against user's Kobo model during build.

## Error handling / ops

- Per-book status in CWA UI: processed / failed-with-reason; no silent drops.
- Logs via existing `dozzle`.
- `gatus` + `homepage` continue monitoring `calibre.dominiksiejak.pl`; healthcheck `curl :8083` kept.
- Rollback: revert `compose.yaml`, run `make apply` in `terraform/portainer`; library data on NAS untouched.

## Deployment steps

1. Edit `stacks/calibre/compose.yaml` (swap service, volume, labels).
2. `make apply` in `terraform/portainer` (sync-portainer → stack apply).
3. Verify healthcheck + Traefik routes (Traefik reloads on container events; new service name picked up automatically).
4. CWA UI config: admin password, folders (if not env-driven), Google Books enrichment on, Kobo sync on + password, ADE key upload.
5. README changelog entry (`### 04.08.2026`).

## Testing (acceptance)

- T1: drop a DRM-free epub → in library as epub+kepub with fetched metadata within ~2 min.
- T2: `/kobo` endpoint responds; OPDS reachable.
- T3 (after ADE key): an Adept-encrypted epub → opens as plain epub in library.
- T4: Kobo device sync shows the new book.
- T5: gatus green; homepage tile OK.

## Non-goals (future)

- n8n email ingest (IMAP → inbox, reusing same pipeline).
- Flat `originals/` archive copy step.
- Google Books API key (only if rate-limited).
- Add CWA image to `scripts/check-stack-updates.py` mapping.
- CWA version-pin follow-up (track releases; script above or cron).

## Verified during build

- CWA env/config keys for incoming + library paths (CWA docs).
- Exact CWA image tag to pin.
- Kobo `/kobo` link menu path on user's model.
