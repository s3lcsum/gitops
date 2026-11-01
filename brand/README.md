# SLAB brand assets (homelab)

## What to use (looks good)

| Need | File |
|------|------|
| **Authentik / email** | `assets/png/logo-horizontal-dark.png`, `assets/png/mark-icon.png` |
| **Full logo (light)** | `assets/logo-horizontal-light.jpg` or `assets/png/lockup-horizontal-1200.png` |
| **Favicon / mark** | `assets/png/mark-32.png` … `mark-512.png` (from JPG mark) |
| **Slabi** | `assets/mascot-reference/slabi-whippet-hero.png`, `slabi-whippet-pose-sheet.jpg`, `assets/jpg/slabi-flow-*.jpg` |
| **Synology DSM** | `assets/nas/dsm-*.jpg` — [nas/README.md](nas/README.md) |
| **UI colors** | `tokens.css` / `tokens.json` |
| **Preview** | Open `preview.html` |

## What we stopped shipping

Auto-traced “SVG logos” (potrace / guessed geometry) — **removed**. They looked wrong next to your exports.

Current `assets/svg/*.svg` files are **thin wrappers** that embed the JPG/PNG above so Argo/Authentik paths can stay `.svg` until someone hand-traces Concept 01 + 02 in Figma/Inkscape.

## Skill sync

Edit under **`brand/`**, then:

```bash
./brand/sync-skill.sh
```

Cursor: `.cursor/skills/brand/` · OpenCode: `.opencode/skills/brand/` · invoke **`/brand`**
