# Calibre: CWA automates, GUI curates — Automation & Plugin Design (2026-08-16)

## Context

- Two services already share one Calibre library (`metadata.db` on NAS at `/mnt/NAS_Shared_Media/books/library`):
  - `calibre-web-automated` (CWA) `crocodilestick/calibre-web-automated:v4.0.6` — `calibre.dominiksiejak.pl`, the automation engine.
  - `calibre` (linuxserver/calibre:9.13.0 desktop GUI) — `calibre-gui.dominiksiejak.pl` (Authentik-protected), now pointing its `library_path` at the same shared library; the curation surface.
- User wants: auto kepub conversion, full metadata enrichment (PL default via LubimyCzytac; books in PL/EN/ES), DeDRM (if possible), automatic sharing with a Kobo on Tailscale, and nice-to-have desktop plugins.
- Empirical findings during investigation:
  - Desktop calibre content server does **not** implement the native Kobo wifi-sync protocol (`/kobo/v1`) — that endpoint only exists in calibre-web/CWA (verified: no `kobo` routes in desktop server code; a second `calibre-server`/`calibredb` refuses to run while the GUI holds the library — single-writer guard).
  - CWA v4.0.6 has a built-in `lubimyczytac.py` metadata provider and `metadata_provider_hierarchy` is already `["ibdb","lubimyczytac","google", ...]`.
  - All `auto_metadata_update_*` flags in `cwa_settings` are on; `auto_convert` on with target `epub`; kepub produced via Kobo sync path (`kepubify`, `config_kobo_sync=1`); `koreader_sync_enabled=1`.
  - DeDRM plugin + `adobekey.py` are baked into the CWA image (`/root/.config/calibre/plugins/DeDRM*`), but no Adobe ADE activation key is uploaded yet.
  - `calibre-customize --list-plugins` runs fine inside the GUI container while the GUI is live (read-only). Write path (`--add-plugin`) likely works but must be verified at build time; fallback is stop → install → start.
- Decisions made with user:
  - Kobo sync: **keep CWA's `/kobo` endpoint** as the sync surface (bigger community, desktop calibre has no native equivalent).
  - Automation model: **CWA automates, GUI curates**.
  - Metadata: **tune existing CWA providers** (no custom provider code).
  - Plugins: **GUI-side (desktop calibre) plugin suite**.
  - Plugin codification: **manifest + Makefile fetch** (pinned sha256; no binaries in git).

## Goal

Books appear on the Kobo automatically (metadata-enriched, DeDRM-stripped when possible, converted to KEPUB) with zero manual steps in the daily path, while the desktop GUI is fully outfitted for manual curation — all reproduced from the gitops repo via a Makefile.

## Architecture (after change)

```
                        ┌───────────────────────────────────────────────┐
  User drops book → NAS │ CWA (calibre.dominiksiejak.pl)                │
  books/inbox           │  ingest → metadata (lubimyczytac #1)          │
                        │  → DeDRM → kepub/epub → SAME metadata.db      │
                        │  → Kobo sync /kobo (Tailscale)                │
                        └───────────────────────────────────────────────┘
                             reads/writes ^── metadata.db (NAS books/library)
                                           │
                            calibre-gui (calibre-gui.dominiksiejak.pl)
                            desktop app, SAME library, curation + plugins
```

- **CWA** remains the automation engine (ingest → metadata → DeDRM → kepub → Kobo sync), unchanged structurally.
- **GUI** remains the curation surface on the same library; gains the plugin suite.
- **Kobo** over Tailscale pulls from CWA `/kobo` (native sync).
- No compose.yaml changes required.

## Components

### 1. CWA config tune (small)

- `metadata_provider_hierarchy`: move `lubimyczytac` to **position 1** so Polish books match LubimyCzytac first. Enabled-map keeps the other providers (google, amazon, dnb, etc.) for EN/ES fallback.
- All `auto_metadata_update_*` flags already on — no change.
- `auto_convert` on, target `epub` (+ kepub via Kobo sync) — no change.
- `config_kobo_sync=1`, `koreader_sync_enabled=1` — no change.
- **DeDRM**: upload Adobe ADE activation key via CWA → Settings → **Adobe** (user action; the only manual step in the design). After that, Adept-DRM'ed shop epubs are stripped.

### 2. GUI plugin suite (manifest + Makefile)

- New `stacks/calibre/plugins/manifest.json` — plugin name → release URL + sha256 for:
  - Quality Tools
  - Manage Series
  - Kobo Utilities (jbouwh/calibre-plugins set)
  - KoboTouchExtended (KTE; adds KEPUB output profile / USB-send conversion)
  - EPUBMerge
  - KindleUnpack
- New `stacks/calibre/Makefile` target `make calibre-plugins`:
  1. reads `manifest.json`,
  2. downloads each zip, verifies sha256,
  3. installs via a transient container:
     `docker run --rm -v calibre_calibre_config:/config linuxserver/calibre:9.13.0 calibre-customize --add-plugin=<zip>`
  4. `docker restart calibre` to load plugins.
- Repo convention respected: no `.sh` scripts, automation via Makefile; no binary blobs committed.

## Data flow

1. User drops a file into `books/inbox` (NAS/SMB).
2. CWA polls (~30s), imports; source format kept byte-identical in the book record; original archived to `/config/processed_books`.
3. Metadata enrichment runs with `lubimyczytac` first (PL), google/others fallback (PL/EN/ES).
4. DeDRM strips Adept when the ADE key is set; clean files pass through untouched.
5. Convert: normalized epub (per `auto_convert_target_format`) + KEPUB generated for Kobo sync.
6. Book live in shared library; visible in both CWA UI and desktop GUI.
7. Kobo wifi sync pulls it over Tailscale from CWA `/kobo`.

## Error handling / ops

- Per-book status in CWA UI (processed / failed-with-reason); no silent drops.
- Plugin install failures surface in Makefile output (sha mismatch → abort; calibre-customize error → visible).
- Logs via existing dozzle; CWA healthcheck unchanged.

## Security

- Plugin zips are third-party binaries fetched over HTTPS with pinned sha256 (protects against tamper/bit-rot; not a guarantee of first-party trust).
- Kobo sync endpoint stays behind existing routing; GUI stays Authentik-gated behind `authentik@docker`.
- No new secrets in the repo. ADE key lives only in CWA config.

## Out of scope (non-goals)

- gatus + homepage tiles for `calibre-gui` (deferred).
- ADE activation key acquisition (user manual step).
- Plugin auto-update / version bump automation (manual manifest edit per update).
- Custom LubimyCzytac provider code (built-in provider suffices).
- Desktop calibre native Kobo wifi sync (does not exist in calibre).

## Verification (acceptance)

- A1: Drop a Polish epub into `books/inbox` → metadata enriched via LubimyCzytac (PL fields, series/description/cover), kepub present, appears in shared library.
- A2: Drop an EN epub → metadata from google/fallback provider; language tagged EN.
- A3: `/kobo` endpoint responds (`https://calibre.dominiksiejak.pl/kobo`).
- A4: `make calibre-plugins` → all six plugins listed in GUI → Preferences → Plugins after `docker restart calibre`.
- A5: (post user ADE key) Adept-epub opens as plain epub.

## Deployment steps

1. Edit CWA `metadata_provider_hierarchy` → `lubimyczytac` first (via CWA UI Settings → Metadata).
2. Add `stacks/calibre/plugins/manifest.json` + `stacks/calibre/Makefile`.
3. Run `make calibre-plugins` (downloads, verifies sha, installs, restarts calibre).
4. User uploads ADE key in CWA → Settings → Adobe.
5. Kobo links to `https://calibre.dominiksiejak.pl/kobo` (device browser sign-in) → normal Sync pulls books.
6. Run acceptance A1–A5.
7. `README.md` changelog entry `### 16.08.2026`.
8. Commit design doc + manifest + Makefile; commit uncommitted `terraform/authentik/locals.tf` calibre-gui addition.

## Testing notes

- CWA config is live state on Portainer; document the one-click settings rather than codifying (no tofu resource for CWA settings).
- `make calibre-plugins` reruns idempotently (calibre-customize warns/replaces existing plugins; restart is cheap).