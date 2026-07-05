# TRaSH Guides via Recyclarr — Design Doc

Date: 2026-07-04
Status: Approved

## Overview

Add Recyclarr to mediabox stack to sync TRaSH guide recommendations for
Sonarr and Radarr. All config via YAML — no raw API calls.

## Architecture

```
mediabox/
├── compose.yaml           ← recyclarr service added
└── recyclarr/
    ├── recyclarr.yml      ← main config (committed)
    ├── secrets.yml        ← API keys (gitignored)
    └── secrets.yml.example ← template (committed)
```

Recyclarr container:
- Runs on `@daily` CRON schedule
- Mounts `/opt/mediabox/recyclarr:/config` (bind mount)
- Reaches sonarr:8989 / radarr:7878 via internal Docker networking
- No web UI, no Traefik labels needed

## Quality Profiles

| App | Profile Name | Type | Cutoff | Notes |
|-----|-------------|------|--------|-------|
| Radarr | SQP-1 WEB (2160p) | WEB-DL 4K only | WEBDL-2160p | No Bluray/Remux |
| Sonarr | WEB-1080p | WEB-DL 1080p | WEB 1080p | Main TV profile |
| Sonarr | WEB-2160p | WEB-DL 2160p | WEB 2160p | Special 4K TV |

### Radarr: WEB-2160p Only

Uses SQP (Streaming Quality Profiles) from TRaSH:
- `radarr-quality-definition-sqp-streaming` — quality sizes optimized for WEB
- `radarr-custom-formats-sqp-1-web-2160p` — audio, HDR, HQ groups, unwanted
- Custom quality profile excludes Bluray-2160p, keeps only WEBDL-2160p + WEBRip-2160p

### Sonarr: WEB-1080p (Main)

Uses TRaSH `sonarr-v4-quality-profile-web-1080p`:
- Quality group: WEB 1080p (WEBDL-1080p + WEBRip-1080p)
- Custom formats: streaming services, audio, source, unwanted
- x265 (no HDR/DV) blocked (-10000)

### Sonarr: WEB-2160p (Special)

Uses TRaSH `sonarr-v4-quality-profile-web-2160p`:
- Quality group: WEB 2160p (WEBDL-2160p + WEBRip-2160p)
- Custom formats: streaming services, audio, source, HDR, unwanted
- DV (w/o HDR fallback) blocked (-10000)

## Language

- Radarr: language left at default (Any), CF scoring naturally prefers English
- Sonarr v4: language left at default (Any), CF scoring prefers English
- Polish/Spanish originals: per-movie override in Radarr UI

TRaSH language custom formats not explicitly added — English results dominate
scoring via standard CF weights.

## Deployment

1. `make sync-portainer` — syncs stacks/ to Portainer host
2. Portainer recreates mediabox stack with Recyclarr
3. Create `/opt/mediabox/recyclarr/secrets.yml` with API keys
4. Recyclarr runs on schedule, syncs profiles & CFs

First run: `docker exec recyclarr recyclarr sync` to force initial sync.

## Files Changed

- `stacks/mediabox/compose.yaml` — add recyclarr service
- `stacks/mediabox/recyclarr/recyclarr.yml` — main config (new)
- `stacks/mediabox/recyclarr/secrets.yml.example` — template (new)
- `stacks/mediabox/recyclarr/.gitignore` — exclude secrets.yml (new)
- `docs/superpowers/specs/2026-07-04-trash-recyclarr-design.md` — this doc
