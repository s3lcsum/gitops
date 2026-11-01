# Slabi mascot

**Name:** Slabi (sounds like “slabby”)
**Canon:** Lavender **whippet** — long neck, deep chest, slim waist, rose ears, big eyes.

## Visual rules

- Fur: lavender + white chest/belly (see `tokens.json` → `color.mascot`).
- **Collar:** purple band + small metal tag (tiny SLAB mark on tag OK).
- **Tail:** thin whip tail; **glowing orb** at tip (connectivity).
- **Never:** large S-shaped fur patch (retired).

## Reference art

| File | Use |
|------|-----|
| `slabi-whippet-hero.png` | Default hero / splash |
| `slabi-whippet-pose-sheet.jpg` | **9 poses** — wave, run, sleep, hard hat + cable, etc. |
| `slabi-whippet-character-sheet.jpg` | Earlier 4-panel sheet (NAS pose) |
| `slabi-v1-fluffy-character-sheet.jpg` | Legacy — do not use |

## Homelab state → art direction

| State | Slabi | Color accent |
|-------|-------|----------------|
| Healthy | Waving, smile | `--slab-success` badge |
| Warning | Head tilt, confused ears | `--slab-warning` |
| Down | Sleep or sad eyes; dim tail glow | `--slab-danger` muted |
| Maintenance | Hard hat + cable (pose sheet) or wave + helmet (future 2D) | `--slab-brand-bright` |
| Deploying | Running / playful leap (pose sheet) or NAS paw (old sheet) | `--slab-brand` |

Status pages (Gatus, Homepage, Grafana annotations): prefer **2D icon** later; until then use geometric **S** + state color ring.

## Service branding (examples)

| Service | Mark | Mascot |
|---------|------|--------|
| Authentik | Horizontal logo on light bg | Optional wave on login side panel |
| Jellyfin | Square icon + title | Server pose splash |
| NAS / MinIO | S icon only | Paw-on-server pose |
| Argo CD | S favicon | Deploying pose in docs |
| Generic app | `icon-s.svg` | Only if UI has room |

Keep third-party trademarks separate — SLAB frames the experience; don’t replace vendor logos inside their UIs unless policy allows.
