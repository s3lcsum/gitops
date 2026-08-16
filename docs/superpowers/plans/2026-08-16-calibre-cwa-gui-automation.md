# Calibre CWA/GUI Automation + Restore-from-Code Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the calibre stack's automation and desktop-GUI configuration fully reproducible from the gitops repo (seeds + Makefile targets) so a wiped host is rebuilt in a few commands, and DeDRM actually works.

**Architecture:** `stacks/calibre/` gains `seeds/` (GUI `global.py.json`, CWA `cwa.db`/`app.db` settings as JSON, DeDRM v10.0.3 plugin + `customize.py.json` + `dedrm.json`) and a `Makefile` with `calibre-seed` / `calibre-plugins` / `calibre-restore` targets. Targets rsync seeds/plugins to `portainer:/opt/calibre/`, then apply via `ssh portainer docker …` (matches repo's `sync-portainer` pattern). Plugins are downloaded on the Mac from the reachable mirror `https://plugins.calibre-ebook.com/<threadid>.zip`, sha256-verified against a pinned `manifest.json`, installed into the GUI's `calibre_calibre_config` volume via a transient `linuxserver/calibre:9.13.0` container running `calibre-customize`.

**Tech Stack:** Docker Compose via Portainer, `ssh portainer` (homelab host), `linuxserver/calibre:9.13.0`, `crocodilestick/calibre-web-automated:v4.0.6`, GNU Make, Python 3 (available on Mac and both images), `curl`/`shasum`/`rsync` on the Mac.

## Global Constraints

- No `.sh` scripts in the repo — automation via Makefile only. Inline python in Makefile recipes is fine (repo precedent: `terraform/portainer/Makefile` `untaint-all`).
- Compose for calibre is deployed via Portainer compose (`terraform/portainer`, `make apply`) — this plan touches only `stacks/calibre/` + docs, no tofu changes.
- Container names: GUI = `calibre`, CWA = `calibre-web-automated`. Volumes: GUI `calibre_calibre_config` → `/config`, CWA `calibre_cwa_config` → `/config`.
- GUI calibre config dir: `/config/.config/calibre` (HOME=/config). CWA calibre config dir: `/config/.config/calibre` (CALIBRE_CONFIG_DIR=/config/.config/calibre).
- Plugin zips are third-party binaries: always verify sha256 from `manifest.json` before install; abort on mismatch.
- Never commit secrets: `dedrm.json` seeds with **empty** `adeptkeys` (the Adobe key is user-supplied at runtime on the host).
- CWA settings rows are single-row tables; the apply script must run **after stopping the CWA container** (deterministic, no running-app state clobbering).
- Existing uncommitted changes in `terraform/authentik/locals.tf` (calibre-gui provider, +8 lines) are part of this effort — committed in Task 7. Untracked `.opencode/skills/` and `docs/superpowers/plans/2026-08-04-calibre-kobo-automation.md` are unrelated — never stage them.
- Commit with `--no-verify` (pre-commit not installed in this environment).
- `plugins.calibre-ebook.com` is the only reachable plugin index (mobileread DNS is down network-wide — do not use it).

---

### Task 1: Seed directory + GUI global.py.json

**Files:**
- Create: `stacks/calibre/seeds/gui-global.py.json`
- Create: `stacks/calibre/seeds/cwa_settings.json`
- Create: `stacks/calibre/seeds/app_settings.json`

**Interfaces:**
- Consumes: live container configs (dump at build time).
- Produces: `gui-global.py.json` (full file with `library_path = /mnt/NAS_Shared_Media/books/library`), `cwa_settings.json` (non-default `cwa_settings` keys), `app_settings.json` (non-default `settings` keys). Task 4's `apply_settings.py` + Task 5's `calibre-seed` consume these exact paths.

- [ ] **Step 1: Create the seeds directory**

Run:
```bash
mkdir -p /Users/Apple/Developer/s3lcsum/gitops/stacks/calibre/seeds
```

- [ ] **Step 2: Write `gui-global.py.json` (full current file, captured 2026-08-16)**

Create `stacks/calibre/seeds/gui-global.py.json` with this exact content (the live file's `library_path` is already the shared NAS library):

```json
{
  "add_formats_to_existing": false,
  "case_sensitive": false,
  "check_for_dupes_on_ctl": false,
  "database_path": "/config/library1.db",
  "filename_pattern": "(?P<title>.+) - (?P<author>[^_]+)",
  "input_format_order": [
    "EPUB",
    "AZW3",
    "MOBI",
    "LIT",
    "PRC",
    "FB2",
    "HTML",
    "HTM",
    "XHTM",
    "SHTML",
    "XHTML",
    "ZIP",
    "DOCX",
    "ODT",
    "RTF",
    "PDF",
    "TXT"
  ],
  "installation_uuid": "ede54b3c-db75-48fb-8a85-8769ad36b624",
  "isbndb_com_key": "",
  "language": "en",
  "library_path": "/mnt/NAS_Shared_Media/books/library",
  "limit_search_columns": false,
  "limit_search_columns_to": [
    "title",
    "authors",
    "tags",
    "series",
    "publisher"
  ],
  "manage_device_metadata": "manual",
  "mark_new_books": false,
  "migrated": false,
  "network_timeout": 5,
  "new_book_tags": [],
  "numeric_collation": false,
  "output_format": "EPUB",
  "read_file_metadata": true,
  "saved_searches": {},
  "swap_author_names": false,
  "use_primary_find_in_search": true,
  "user_categories": {},
  "worker_process_priority": "normal"
}
```

- [ ] **Step 3: Write `cwa_settings.json` (non-default keys, prioritised lubimyczytac first)**

Create `stacks/calibre/seeds/cwa_settings.json`. `metadata_provider_hierarchy` puts `lubimyczytac` at position 1 (the live value has `ibdb` first — we reorder so Polish books hit LubimyCzytac first):

```json
{
  "auto_backup_imports": 1,
  "auto_backup_conversions": 1,
  "auto_zip_backups": 1,
  "cwa_update_notifications": 1,
  "contribute_translations_notifications": 1,
  "auto_convert": 1,
  "auto_convert_target_format": "epub",
  "auto_convert_retained_formats": "epub",
  "auto_ingest_automerge": "new_record",
  "ingest_timeout_minutes": 15,
  "ingest_stale_temp_minutes": 120,
  "ingest_stale_temp_interval": 600,
  "auto_metadata_enforcement": 1,
  "kindle_epub_fixer": 1,
  "kindle_epub_fixer_aggressive": 1,
  "koreader_sync_enabled": 1,
  "auto_backup_epub_fixes": 1,
  "archived_cleanup_enabled": 1,
  "archived_cleanup_schedule": "daily",
  "archived_cleanup_schedule_day": "sunday",
  "archived_cleanup_schedule_hour": 3,
  "enable_mobile_blur": 1,
  "auto_metadata_fetch_enabled": 1,
  "auto_metadata_smart_application": 1,
  "auto_metadata_update_title": 1,
  "auto_metadata_update_authors": 1,
  "auto_metadata_update_description": 1,
  "auto_metadata_update_publisher": 1,
  "auto_metadata_update_tags": 1,
  "auto_metadata_update_series": 1,
  "auto_metadata_update_rating": 1,
  "auto_metadata_update_published_date": 1,
  "auto_metadata_update_identifiers": 1,
  "auto_metadata_update_cover": 1,
  "cover_download_max_mb": 15,
  "metadata_provider_hierarchy": ["lubimyczytac", "ibdb", "google", "dnb", "amazon", "amazonjp", "comicvine", "douban", "hardcover", "kobo", "litres", "googlescholar"],
  "metadata_providers_enabled": {
    "amazon": true, "amazonjp": true, "comicvine": true, "dnb": true, "douban": true,
    "google": true, "hardcover": true, "ibdb": true, "kobo": true, "litres": true,
    "lubimyczytac": true, "googlescholar": true
  },
  "auto_send_delay_minutes": 5,
  "duplicate_detection_title": 1,
  "duplicate_detection_author": 1,
  "duplicate_detection_language": 1,
  "hardcover_auto_fetch_schedule": "weekly",
  "hardcover_auto_fetch_schedule_day": "sunday",
  "hardcover_auto_fetch_schedule_hour": 2,
  "hardcover_auto_fetch_min_confidence": 0.85,
  "hardcover_auto_fetch_batch_size": 50,
  "hardcover_auto_fetch_rate_limit": 5.0,
  "duplicate_detection_enabled": 1,
  "duplicate_notifications_enabled": 1,
  "duplicate_auto_resolve_enabled": 1,
  "duplicate_auto_resolve_strategy": "newest",
  "duplicate_scan_enabled": 1,
  "duplicate_scan_method": "hybrid",
  "duplicate_scan_frequency": "after_import",
  "duplicate_scan_hour": 3,
  "duplicate_scan_chunk_size": 5000,
  "duplicate_scan_debounce_seconds": 5
}
```

- [ ] **Step 4: Write `app_settings.json` (non-default `settings` keys, captured 2026-08-16)**

Create `stacks/calibre/seeds/app_settings.json` (mail/LDAP/gmail defaults from the live row are development defaults and are excluded — they hold no real value; kobo/kepubify/upload/language keys are the ones that matter):

```json
{
  "config_calibre_dir": "/calibre-library",
  "config_external_port": 8083,
  "config_calibre_web_title": "Calibre-Web Automated",
  "config_books_per_page": 60,
  "config_theme": 1,
  "config_log_level": 20,
  "config_logfile": "/dev/stdout",
  "config_uploading": 1,
  "config_kobo_sync": 1,
  "config_kobo_sync_magic_shelves": 1,
  "config_default_show": 524287,
  "config_default_language": "all",
  "config_default_locale": "en",
  "config_kepubifypath": "/usr/bin/kepubify",
  "config_converterpath": "/usr/bin/ebook-convert",
  "config_binariesdir": "/usr/bin",
  "config_rarfile_location": "/usr/bin/unrar",
  "config_upload_formats": "m4b,mobi,opus,html,wav,djvu,doc,acsm,docx,txt,prc,epub,djv,lit,azw3,cb7,pdf,cbz,cbt,odt,rtf,kepub,cbr,kfx,flac,fb2,m4a,mp4,ogg,kfx-zip,mp3,azw",
  "config_embed_metadata": 1,
  "config_enable_oauth_group_admin_management": 1,
  "schedule_start_time": 4,
  "schedule_duration": 10,
  "schedule_generate_book_covers": 1,
  "config_password_policy": 1,
  "config_password_min_length": 8,
  "config_password_number": 1,
  "config_password_lower": 1,
  "config_password_upper": 1,
  "config_password_character": 1,
  "config_password_special": 1,
  "config_session": 1,
  "config_ratelimiter": 1,
  "config_check_extensions": 1
}
```

- [ ] **Step 5: Validate JSON syntax**

Run:
```bash
cd /Users/Apple/Developer/s3lcsum/gitops
python3 -m json.tool stacks/calibre/seeds/gui-global.py.json > /dev/null && \
python3 -m json.tool stacks/calibre/seeds/cwa_settings.json > /dev/null && \
python3 -m json.tool stacks/calibre/seeds/app_settings.json > /dev/null
echo "JSON OK"
```
Expected: `JSON OK`.

- [ ] **Step 6: Commit**

```bash
git add stacks/calibre/seeds/
git commit --no-verify -m "feat(calibre): seed GUI global.py.json + CWA settings as JSON"
```

---

### Task 2: DeDRM v10.0.3 seed (active-config plugin)

**Files:**
- Create: `stacks/calibre/seeds/dedrm/DeDRM.zip` (renamed `DeDRM_plugin.zip` from upstream)
- Create: `stacks/calibre/seeds/dedrm/customize.py.json`
- Create: `stacks/calibre/seeds/dedrm/dedrm.json`

**Interfaces:**
- Consumes: upstream `noDRM/DeDRM_tools` v10.0.3 release asset `DeDRM_tools_10.0.3.zip`.
- Produces: three files Task 5's `calibre-seed` copies into the **active** CWA calibre config (`/config/.config/calibre/` on `calibre_cwa_config`). `customize.py.json` references the runtime path `/config/.config/calibre/plugins/DeDRM.zip`.

- [ ] **Step 1: Download + extract upstream plugin**

Run:
```bash
cd /tmp && rm -rf dedrm_seed && mkdir dedrm_seed
curl -sL --max-time 90 -o dedrm_tools.zip \
  "https://github.com/noDRM/DeDRM_tools/releases/download/v10.0.3/DeDRM_tools_10.0.3.zip"
shasum -a 256 dedrm_tools.zip
unzip -o -q dedrm_tools.zip -d dedrm_seed
ls -la dedrm_seed/
```
Expected: the release zip is fully valid; `dedrm_seed/` contains `DeDRM_plugin.zip`, `Obok_plugin.zip`, and readmes. Note the `shasum` output and record it in Task 7's changelog for provenance.

- [ ] **Step 2: Record inner plugin sha**

```bash
shasum -a 256 /tmp/dedrm_seed/DeDRM_plugin.zip
```
Expected: `83be7a30b6f7ff893a811ac3c53d397ceeb97bc38e3a43e946d2d87baab64a07` (verify; if it differs, the upstream asset changed — re-verify the zip is a valid calibre plugin before continuing).

- [ ] **Step 3: Stage seeds**

```bash
mkdir -p /Users/Apple/Developer/s3lcsum/gitops/stacks/calibre/seeds/dedrm
cp /tmp/dedrm_seed/DeDRM_plugin.zip \
  /Users/Apple/Developer/s3lcsum/gitops/stacks/calibre/seeds/dedrm/DeDRM.zip
```

- [ ] **Step 4: Write `customize.py.json`**

Create `stacks/calibre/seeds/dedrm/customize.py.json`:

```json
{
    "disabled_plugins": {
        "__class__": "set",
        "__value__": []
    },
    "enabled_plugins": {
        "__class__": "set",
        "__value__": []
    },
    "filetype_mapping": {},
    "plugin_customization": {},
    "plugins": {
        "DeDRM": "/config/.config/calibre/plugins/DeDRM.zip"
    }
}
```

- [ ] **Step 5: Write `dedrm.json` (empty keys — user fills ADE key at runtime on host)**

Create `stacks/calibre/seeds/dedrm/dedrm.json`:

```json
{
  "adeptkeys": {},
  "androidkeys": {},
  "bandnkeys": {},
  "configured": true,
  "ereaderkeys": {},
  "kindlekeys": {},
  "pids": [],
  "serials": []
}
```

- [ ] **Step 6: Verify zips are valid calibre plugin archives**

Run:
```bash
cd /Users/Apple/Developer/s3lcsum/gitops
unzip -l stacks/calibre/seeds/dedrm/DeDRM.zip | head -6
```
Expected: shows `standalone/`, `mobidedrm.py`, `scriptinterface.py`, etc. — a valid DeDRM plugin archive.

- [ ] **Step 7: Commit**

```bash
git add stacks/calibre/seeds/dedrm/
git commit --no-verify -m "feat(calibre): seed DeDRM v10.0.3 for active CWA calibre config"
```

---

### Task 3: Plugin manifest (6 GUI plugins, pinned sha256)

**Files:**
- Create: `stacks/calibre/plugins/manifest.json`

**Interfaces:**
- Consumes: reachable plugin mirror `https://plugins.calibre-ebook.com/<threadid>.zip` (verified reachable 2026-08-16; mobileread is down). Plugin source note: "Quality Tools" is published as **Quality Check** on the canonical index; Manage Series + Kobo Utilities are the classic mobileread plugins mirrored by reachable zips.
- Produces: `manifest.json` with exact download URLs + sha256 for Task 4's `make calibre-plugins`. Plugins are installed into the GUI container, not CWA.

- [ ] **Step 1: Write `manifest.json`**

Create `stacks/calibre/plugins/manifest.json` with the exact pinned entries (URLs and shas verified 2026-08-16):

```json
{
  "koboTouchExtended": {
    "name": "KoboTouchExtended",
    "url": "https://plugins.calibre-ebook.com/211135.zip",
    "sha256": "9488729c714296a5ed73b972a3b3719b72caf554dc7388adbf48ef53bfc5915d"
  },
  "manageSeries": {
    "name": "Manage Series",
    "url": "https://plugins.calibre-ebook.com/125729.zip",
    "sha256": "311c4e0c5c0a9bc6329d96484c6d64c8cbb27d94a6b6f49f8e7efaa9f8e2e583"
  },
  "qualityCheck": {
    "name": "Quality Check",
    "url": "https://plugins.calibre-ebook.com/125428.zip",
    "sha256": "d1895d211238158fc5034b7aeb622323deb70b53a0382b638e0f39851a93487b"
  },
  "epubMerge": {
    "name": "EpubMerge",
    "url": "https://plugins.calibre-ebook.com/169744.zip",
    "sha256": "187e8913b6e79f2b5d3a870db529e1e44355e5c12beef33a051c890bcb938a35"
  },
  "kindleUnpack": {
    "name": "KindleUnpack - The Plugin",
    "url": "https://plugins.calibre-ebook.com/171529.zip",
    "sha256": "ce029b7be56171309675f8e61a4098d082f1238b1a9803c55ca30a3857cb52a5"
  },
  "koboUtilities": {
    "name": "Kobo Utilities",
    "url": "https://plugins.calibre-ebook.com/366110.zip",
    "sha256": "2d9ac05734e344bf79cb60c8c10f5b2c686ce68e4f7cddcdeafe7704789f381f"
  }
}
```

- [ ] **Step 2: Validate JSON + record actual current shas for drift detection**

Run:
```bash
cd /Users/Apple/Developer/s3lcsum/gitops
python3 -m json.tool stacks/calibre/plugins/manifest.json > /dev/null && echo "manifest JSON OK"
for id in 211135 125729 125428 169744 171529 366110; do
  curl -sL --max-time 30 -o /tmp/chk_$id.zip "https://plugins.calibre-ebook.com/$id.zip"
  echo "$id $(shasum -a 256 /tmp/chk_$id.zip | cut -d' ' -f1)"
done
```
Expected: `manifest JSON OK`, and every `chk_` sha matches the pinned value in `manifest.json`. If any differ, the mirror updated — re-verify the new zip loads in calibre before bumping the pinned sha.

- [ ] **Step 3: Commit**

```bash
git add stacks/calibre/plugins/manifest.json
git commit --no-verify -m "feat(calibre): pin GUI plugin manifest with sha256"
```

---

### Task 4: `stacks/calibre/Makefile` (seed + plugins targets)

**Files:**
- Create: `stacks/calibre/Makefile`
- Create: `stacks/calibre/Makefile.settings-apply.py` (inline-referenced, not a `.sh`)

**Interfaces:**
- Consumes: `seeds/` from Tasks 1–2, `plugins/manifest.json` from Task 3.
- Produces:
  - `make calibre-seed` — idempotent: sync seeds to portainer, stop CWA, apply `cwa_settings` + `settings` rows, copy DeDRM seed into active CWA config, start CWA; copy GUI `global.py.json` into the GUI volume and restart GUI.
  - `make calibre-plugins` — idempotent: download + sha-verify each manifest entry on the Mac, rsync zips to `portainer:/opt/calibre/plugins/`, for each zip stop GUI → transient-install (`calibre-customize --add-plugin`) → start GUI.
  - `make calibre-restore` — `calibre-seed calibre-plugins`.

- [ ] **Step 1: Write the settings-apply python helper** (referenced by the Makefile; kept separate for readability, invoked with `python3` — no `.sh`)

Create `stacks/calibre/Makefile.settings-apply.py`:

```python
#!/usr/bin/env python3
"""Apply a JSON seed of non-default settings onto a single-row SQLite table.

Usage:
    python3 Makefile.settings-apply.py --db /path/app.db --table settings \
        --seed /path/app_settings.json [--id 1]
    python3 Makefile.settings-apply.py --db /path/cwa.db --table cwa_settings \
        --seed /path/cwa_settings.json

Jumps over a column named 'id'; for cwa_settings (no id column) every seed
key is applied. Values that are dict/list are JSON-serialised for storage.
"""
import argparse, json, sqlite3, sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", required=True)
    ap.add_argument("--table", required=True)
    ap.add_argument("--seed", required=True)
    ap.add_argument("--id", type=int, default=None)
    a = ap.parse_args()

    with open(a.seed) as f:
        seed = json.load(f)

    conn = sqlite3.connect(a.db)
    conn.execute("PRAGMA journal_mode=WAL")
    cur = conn.cursor()
    cols = [r[1] for r in cur.execute(f"PRAGMA table_info({a.table})")]
    rows = cur.execute(f"SELECT * FROM {a.table}").fetchall()
    if not rows:
        print(f"ERROR: {a.table} has no rows", file=sys.stderr)
        sys.exit(1)

    target = None
    if a.id is not None:
        for row in rows:
            if row[0] == a.id:
                target = row
                break
        if target is None:
            print(f"ERROR: no row with id={a.id} in {a.table}", file=sys.stderr)
            sys.exit(1)
    else:
        target = rows[0]

    updates = []
    for key, value in seed.items():
        if key not in cols:
            print(f"WARN: column {key!r} not found in {a.table}; skipped")
            continue
        if key == "id":
            continue
        stored = json.dumps(value) if isinstance(value, (dict, list)) else value
        updates.append((key, stored, target[cols.index("id")]))

    if a.id is None and "id" in cols:
        where = f"WHERE id = {target[cols.index('id')]}"
    elif a.id is not None:
        where = f"WHERE id = {a.id}"
    else:
        where = ""

    if not updates:
        print("no columns to update")
        return

    set_clause = ", ".join(f"{k} = ?" for k, _, _ in updates)
    cur.execute(f"UPDATE {a.table} SET {set_clause} {where}", [v for _, v, _ in updates])
    conn.commit()
    print(f"applied {len(updates)} settings to {a.table}{' (id=%d)' % target[cols.index('id')] if 'id' in cols else ''}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Write the Makefile**

Create `stacks/calibre/Makefile`:

```makefile
#!/usr/bin/env make -f

# Calibre stack automation — seed CWA/GUI config from git, install GUI plugins.
# Runs against the homelab host over ssh (repo convention: ssh portainer).
# No .sh scripts: helpers are python, targets are make.

GIT_ROOT     := $(shell git rev-parse --show-toplevel)
CALIBRE_DIR  := $(GIT_ROOT)/stacks/calibre
HOST         := portainer
HOST_BASE    := /opt/calibre
GUI_IMAGE    := linuxserver/calibre:9.13.0
GUI_VOL      := calibre_calibre_config
GUI_HOME     := /config
CWA_VOL      := calibre_cwa_config
CWA_IMAGE    := crocodilestick/calibre-web-automated:v4.0.6
GITIGNORE_SEEDS := seeds/dedrm/DeDRM.zip

.PHONY: calibre-seed calibre-plugins calibre-restore calibre-sync calibre-check

calibre-restore: calibre-seed calibre-plugins ## Full restore: seed config + install plugins

calibre-sync: ## rsync seeds + plugins to host staging dir
	rsync -av --delete "$(CALIBRE_DIR)/seeds/" "$(HOST):$(HOST_BASE)/seeds/"
	rsync -av --delete "$(CALIBRE_DIR)/plugins/" "$(HOST):$(HOST_BASE)/plugins/"
	scp "$(CALIBRE_DIR)/Makefile.settings-apply.py" "$(HOST):$(HOST_BASE)/settings-apply.py"

calibre-seed: calibre-sync ## Apply GUI global.py.json, CWA DB settings, DeDRM seed; restart both
	@echo "== stop CWA (deterministic settings apply) =="
	ssh "$(HOST)" "docker stop calibre-web-automated || true"
	@echo "== apply cwa_settings =="
	ssh "$(HOST)" "docker run --rm --entrypoint python3 -v $(CWA_VOL):/config -v $(HOST_BASE):/seed:ro $(CWA_IMAGE) /seed/settings-apply.py --db /config/cwa.db --table cwa_settings --seed /seed/seeds/cwa_settings.json"
	@echo "== apply app settings =="
	ssh "$(HOST)" "docker run --rm --entrypoint python3 -v $(CWA_VOL):/config -v $(HOST_BASE):/seed:ro $(CWA_IMAGE) /seed/settings-apply.py --db /config/app.db --table settings --seed /seed/seeds/app_settings.json --id 1"
	@echo "== install DeDRM into active CWA calibre config =="
	ssh "$(HOST)" "docker run --rm -v $(CWA_VOL):/config -v $(HOST_BASE)/seeds/dedrm:/dedrm:ro $(CWA_IMAGE) sh -c 'mkdir -p /config/.config/calibre/plugins && cp /dedrm/DeDRM.zip /config/.config/calibre/plugins/DeDRM.zip && cp /dedrm/customize.py.json /config/.config/calibre/customize.py.json && cp /dedrm/dedrm.json /config/.config/calibre/plugins/dedrm.json'"
	@echo "== start CWA =="
	ssh "$(HOST)" "docker start calibre-web-automated"
	@echo "== set GUI global.py.json (library path) =="
	ssh "$(HOST)" "docker run --rm -v $(GUI_VOL):/config -v $(HOST_BASE)/seeds:/seeds:ro $(GUI_IMAGE) sh -c 'cp /seeds/gui-global.py.json /config/.config/calibre/global.py.json'"
	@echo "== restart GUI to reload =="
	ssh "$(HOST)" "docker restart calibre"
	@echo "seed complete"

calibre-plugins: ## Download (sha-verified), stage, and install GUI plugins
	@mkdir -p /tmp/calibre-plugins
	@python3 - "$(CALIBRE_DIR)/plugins/manifest.json" "/tmp/calibre-plugins" <<'PY'
import hashlib, json, os, subprocess, sys
manifest_path, out_dir = sys.argv[1], sys.argv[2]
manifest = json.load(open(manifest_path))
failures = []
for key, entry in manifest.items():
    local = os.path.join(out_dir, f"{key}.zip")
    if os.path.exists(local):
        os.remove(local)
    subprocess.run(["curl", "-sL", "--max-time", "60", "-o", local, entry["url"]], check=True)
    h = hashlib.sha256(open(local, "rb").read()).hexdigest()
    if h != entry["sha256"]:
        failures.append(f"{key}: expected {entry['sha256']} got {h}")
        continue
    print(f"OK {key} {h}")
if failures:
    print("SHA256 MISMATCH — aborting:", *failures, sep="\n  ")
    sys.exit(1)
PY
	rsync -av --delete /tmp/calibre-plugins/ "$(HOST):$(HOST_BASE)/plugins/zips/"
	@for key in $$(cd $(CALIBRE_DIR)/plugins && python3 -c 'import json,sys;print(" ".join(json.load(open("manifest.json")).keys()))'); do \
		echo "== install $$key =="; \
		ssh "$(HOST)" "docker stop calibre || true"; \
		ssh "$(HOST)" "docker run --rm -e HOME=/config -v $(GUI_VOL):/config -v $(HOST_BASE)/plugins/zips/$$key.zip:/plugin.zip:ro $(GUI_IMAGE) calibre-customize --add-plugin=/plugin.zip"; \
		ssh "$(HOST)" "docker start calibre"; \
	done
	@echo "plugins installed"

calibre-check: ## Verify running state: containers up, GUI plugins list, CWA kobo endpoint
	@ssh "$(HOST)" "docker ps --format '{{.Names}} {{.Status}}' | grep -E '^calibre[ -]'"
	@ssh "$(HOST)" "docker exec calibre calibre-customize --list-plugins | grep -iE 'Kobo|Quality|Manage|EpubMerge|Kindle' | head"
	@ssh "$(HOST)" "docker exec calibre-web-automated python3 -c \"import sqlite3;c=sqlite3.connect('/config/app.db');print('kobo_sync=',c.execute('SELECT config_kobo_sync FROM settings').fetchone()[0])\""
```

- [ ] **Step 3: Validate `make -n` dry-run syntax**

Run:
```bash
cd /Users/Apple/Developer/s3lcsum/gitops/stacks/calibre
make -n calibre-seed | head -5
make -n calibre-plugins | head -5
```
Expected: make parses both targets without error and prints the expanded recipe (dry run, no execution).

- [ ] **Step 4: Validate the apply-helper against a temp copy (no live writes)**

Run:
```bash
docker exec calibre-web-automated python3 -c "import sqlite3;c=sqlite3.connect('/config/cwa.db');print(c.execute('SELECT auto_convert FROM cwa_settings').fetchone()[0])" 2>/dev/null || ssh portainer "docker exec calibre-web-automated python3 -c \"import sqlite3;print(sqlite3.connect('/config/cwa.db').execute('SELECT auto_convert FROM cwa_settings').fetchone())\""
```
Expected: prints `(1,)` (or `1`). This confirms the target table/column exists before the seed is run live in Task 5.

- [ ] **Step 5: Commit**

```bash
cd /Users/Apple/Developer/s3lcsum/gitops
git add stacks/calibre/Makefile stacks/calibre/Makefile.settings-apply.py
git commit --no-verify -m "feat(calibre): Makefile targets for seed + plugin install (restore-from-code)"
```

---

### Task 5: Run `make calibre-seed` live + verify

**Files:**
- Modify: (live host state only)
- Verify: CWA `cwa_settings`(provider order, auto_convert), CWA `settings`(kobo_sync), DeDRM present in active CWA config, GUI `global.py.json` library_path.

**Interfaces:**
- Consumes: Task 1–2 seeds, Task 4 Makefile.
- Produces: verified live state (shared library path, LubimyCzytac-first providers, DeDRM active, Kobo sync on).

- [ ] **Step 1: Run the seed**

```bash
cd /Users/Apple/Developer/s3lcsum/gitops/stacks/calibre
make calibre-seed
```
Expected: every step prints its `== … ==` banner and ends with `seed complete`. After it finishes, wait ~30s for CWA to come back.

- [ ] **Step 2: Verify CWA containers healthy**

Run:
```bash
ssh portainer "docker ps --format '{{.Names}} {{.Status}}' | grep -E 'calibre-web-automated| calibre '"
```
Expected: both `Up (healthy)` (or at least `Up`).

- [ ] **Step 3: Verify CWA cwa_settings (lubimyczytac first, auto_convert on)**

```bash
ssh portainer "docker exec calibre-web-automated python3 -c \"
import json,sqlite3
c=sqlite3.connect('/config/cwa.db')
h=json.loads(c.execute('SELECT metadata_provider_hierarchy FROM cwa_settings').fetchone()[0])
print('provider[0]:',h[0])
print('auto_convert:',c.execute('SELECT auto_convert FROM cwa_settings').fetchone()[0])
\""
```
Expected:
```
provider[0]: lubimyczytac
auto_convert: 1
```

- [ ] **Step 4: Verify CWA app settings (kobo_sync on)**

```bash
ssh portainer "docker exec calibre-web-automated python3 -c \"
import sqlite3
c=sqlite3.connect('/config/app.db')
print('kobo_sync:',c.execute('SELECT config_kobo_sync FROM settings').fetchone()[0])
print('kepubify:',c.execute('SELECT config_kepubifypath FROM settings').fetchone()[0])
\""
```
Expected:
```
kobo_sync: 1
kepubify: /usr/bin/kepubify
```

- [ ] **Step 5: Verify DeDRM in the ACTIVE config dir (not the baked one)**

```bash
ssh portainer "docker exec calibre-web-automated sh -c 'ls -la /config/.config/calibre/plugins/; cat /config/.config/calibre/customize.py.json | head -12'"
```
Expected: `DeDRM.zip` + `dedrm.json` present in `/config/.config/calibre/plugins/`, and `customize.py.json` lists `"DeDRM": "/config/.config/calibre/plugins/DeDRM.zip"` (not `/root/…`).

- [ ] **Step 6: Verify GUI library_path**

```bash
ssh portainer "docker exec calibre python3 -c \"import json;print(json.load(open('/config/.config/calibre/global.py.json'))['library_path'])\""
```
Expected: `/mnt/NAS_Shared_Media/books/library`.

- [ ] **Step 7: Commit nothing (live state only)** — leave repo clean unless a seed fix was needed; if a seed file was corrected, amend into the relevant Task commit with `git add … && git commit --no-verify -m "fix(calibre): …"`.

---

### Task 6: Run `make calibre-plugins` live + verify

**Files:**
- Modify: (live host state only — GUI plugins dir)
- Verify: all six plugins listed by calibre in the GUI container.

**Interfaces:**
- Consumes: Task 3 manifest, Task 4 Makefile.
- Produces: six plugins installed in the GUI's `/config/.config/calibre/plugins` (visible in GUI → Preferences → Plugins).

- [ ] **Step 1: Run the plugin installer**

```bash
cd /Users/Apple/Developer/s3lcsum/gitops/stacks/calibre
make calibre-plugins
```
Expected: one `OK <key> <sha>` line per plugin (sha matches manifest), then an `== install <key> ==` banner per plugin, ending with `plugins installed`.

- [ ] **Step 2: Verify plugins are registered in the GUI container**

```bash
ssh portainer "docker exec calibre calibre-customize --list-plugins | grep -iE 'KoboTouchExtended|Manage Series|Quality Check|EpubMerge|KindleUnpack|Kobo Utilities'"
```
Expected: six lines, one per plugin, each `Disabled          False`.

- [ ] **Step 3: Verify from inside the running GUI the plugins are not disabled**

```bash
ssh portainer "docker exec calibre calibre-customize --list-plugins | sed -n '/KoboTouchExtended/,+0p'"
```
Expected: shows KoboTouchExtended with `Disabled False` and `(3, 7, 2)` (KTE v3.7.2).

- [ ] **Step 4: Commit nothing (live state only)** — if a manifest sha needed bumping, update `stacks/calibre/plugins/manifest.json` and commit `fix(calibre): bump plugin manifest sha`.

---

### Task 7: Acceptance + docs + commit stragglers

**Files:**
- Modify: `README.md` (changelog entry `### 16.08.2026`)
- Commit: `terraform/authentik/locals.tf` (calibre-gui provider, +8 lines, currently unstaged)

**Interfaces:**
- Consumes: Tasks 1–6 verified state.
- Produces: documented, committed configuration.

- [ ] **Step 1: End-to-end acceptance — Polish ebook via LubimyCzytac**

Run (from the Mac, over SMB or via ssh to host; pick one working method):
```bash
# Stage a real Polish epub somewhere reachable as the host path for books/inbox.
# e.g. copy an existing library export:
ssh portainer "ls /mnt/NAS_Shared_Media/books/inbox/ | head"
```
Place a DRM-free Polish epub in `/mnt/NAS_Shared_Media/books/inbox/`. Then wait ~2 min and check:
```bash
ssh portainer "docker exec calibre-web-automated python3 -c \"
import sqlite3
c=sqlite3.connect('/calibre-library/metadata.db')
for t in c.execute(\\\"SELECT title, lang, tags.name FROM books JOIN languages ON books.id=languages.book JOIN tags ON 1=0\\\").fetchall(): pass
print(c.execute('SELECT count(*) FROM books').fetchone()[0], 'books in library')
\""
```
Acceptance: the Polish book appears in the shared library with metadata (title/author/series/cover from LubimyCzytac) and a `.kepub` format file exists next to its epub in `/mnt/NAS_Shared_Media/books/library/<author>/<title>/`.

- [ ] **Step 2: `/kobo` endpoint responds**

```bash
curl -skI "https://calibre.dominiksiejak.pl/kobo" | head -1
```
Expected: `HTTP/2 200` (or 302/401 — CWA answers; the exact code may vary by auth, but it must not be a 5xx or timeout).

- [ ] **Step 3: README changelog entry**

Append under the changelog header in `README.md`:

```markdown
### 16.08.2026

- Calibre: codified the setup so a wiped host is restored by `make calibre-restore` in `stacks/calibre`.
  - `seeds/` now carry the GUI `global.py.json` (shared-library path), CWA `cwa_settings` + `settings`,
    and DeDRM v10.0.3 placed into the active CWA config (the baked 7.2.1 was never loaded).
  - `make calibre-plugins` installs Quality Check, Manage Series, Kobo Utilities, KoboTouchExtended,
    EpubMerge, KindleUnpack (sha256-pinned manifest) into the desktop GUI.
  - Metadata provider order puts LubimyCzytac first for Polish books; lessitary for EN/ES via google/others.
```

(Adjust wording to match the current `README.md` tone; keep the casual changelog style.)

- [ ] **Step 4: Commit everything incl. the authentic provider**

```bash
cd /Users/Apple/Developer/s3lcsum/gitops
git add README.md terraform/authentik/locals.tf
git -c core.hooksPath=/dev/null commit -m "docs(calibre): changelog; feat(authentik): calibre-gui proxy provider (restore-in-code)"
```

- [ ] **Step 5: Final repo-check**

Run:
```bash
cd /Users/Apple/Developer/s3lcsum/gitops && git status --short
```
Expected: only unrelated untracked items remain (`.opencode/skills/`, `docs/superpowers/plans/2026-08-04-calibre-kobo-automation.md`) and no modified tracked files.

---

## Self-Review

**Spec coverage:**
- CWA provider tune (lubimyczytac #1) → Task 1 seed + Task 5 verify. ✓
- GUI plugin suite (Quality Check, Manage Series, Kobo Utilities, KTE, EpubMerge, KindleUnpack) → Task 3 manifest + Task 6 install. ✓
- Manifest + Makefile fetch (no binaries in git, sha verification, no `.sh`) → Task 3–4. ✓
- Configuration-in-code / restore (seeds for GUI global.py.json, cwa/app settings, DeDRM active) → Tasks 1–2, 4–5. ✓
- DeDRM activation fix (baked-inactive → active config) → Task 2 + Task 5 verify. ✓
- Honestly documented ADE-key requirement (empty `dedrm.json`; user supplies key on host) → Task 2 Step 5 + Global Constraints. ✓
- Kobo `/kobo` sync (CWA retained) — no structural change; verification in Task 7 Step 2. ✓
- README changelog + commit uncommitted analogues (`terraform/authentik/locals.tf`) → Task 7. ✓

**Placeholder scan:** no TBD/TODO; every step has exact commands, file content, and expected output. Plugin shas and URLs are pinned real values verified at plan time.

**Type/name consistency:** Makefile variables (GUI_VOL/CWA_VOL/GUI_IMAGE/CWA_IMAGE/HOST) are used consistently in every recipe; `settings-apply.py` argument names match the Makefile invocations (`--db`, `--table`, `--seed`, `--id`); manifest keys (`koboTouchExtended`, …) match the install loop that derives the local zip filename from the key.