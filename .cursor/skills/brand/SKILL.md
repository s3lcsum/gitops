---
name: brand
description: >-
  SLAB homelab visual identity — logo lockup (geometric S + connected SLAB),
  dominiksiejak.pl, purple/violet tokens, Slabi whippet mascot, icons and banners.
  Use when the user invokes /brand, asks for homelab branding, Authentik/Jellyfin/NAS
  logos, favicons, wallpapers, UI theming, or Cursor/OpenCode app colors.
disable-model-invocation: true
---

# SLAB brand (`/brand`)

Homelab identity for **dominiksiejak.pl**. Not generic “SLAB” industry branding — this skill is the purple GitOps / homelab system.

## Quick facts

| Item | Value |
|------|--------|
| Name | **SLAB** |
| Domain | **dominiksiejak.pl** (always lowercase in lockups) |
| Symbol | Concept **01** — geometric **S**, endpoint nodes |
| Wordmark | Concept **02** — connected **SLAB** lettering |
| Mascot | **Slabi** — lavender whippet, collar + glowing tail; **no** S on fur |
| φ | `1.6180339887` — spacing grid in [logo-spec.md](logo-spec.md) |

## When applying this skill

1. Read [tokens.json](tokens.json) for exact hex/RGB (light, dark, mascot).
2. Use [tokens.css](tokens.css) for web/CSS (`data-slab-theme="dark"` toggles dark).
3. Pick assets from [layouts.md](layouts.md) — square, vertical, wide, wallpaper.
4. Mascot rules and poses: [mascot.md](mascot.md).
5. Logo geometry: [logo-spec.md](logo-spec.md).

**Preview locally:** open [preview.html](preview.html) in a browser (file:// or simple static server).

**Repo paths:** skill entry `.cursor/skills/brand/` and `.opencode/skills/brand/` (same content); deployable assets `brand/assets/`.

## Asset priority (production)

1. **Authentik + email (dark band):** `assets/png/logo-horizontal-dark.png` on `#14101C`.
2. **Favicon / app icon:** `assets/png/mark-icon.png` (Concept **01** on black).
3. **Full lockup (light UI):** `assets/logo-horizontal-light.jpg` — faithful Concept **02** wordmark.
4. **Mark crops:** `assets/png/mark-*.png` from light JPG when `#F9F8FD` background needed.
5. **SVG files:** wrappers embedding rasters — **not** hand-traced vectors yet.

Do **not** use auto-traced path SVGs or system-font “SLAB” text for customer-facing UI.

## Asset priority (deprecated — do not use)

~~Hand-drawn or potrace SVG paths~~ — removed; they did not match your artwork.

## Homelab service checklist

When branding a service (Authentik, Jellyfin, Homepage, NAS UI, etc.):

- [ ] Theme CSS uses `--slab-*` variables from `tokens.css`.
- [ ] Favicon = `assets/png/mark-icon.png` (Authentik) or `mark-32.png` on light UI.
- [ ] Login or email header = `png/logo-horizontal-dark.png` on `#14101C`; light pages = `logo-horizontal-light.jpg` on `#F9F8FD`.
- [ ] Large square tile = `png/mark-512.png` on brand background if needed.
- [ ] Status/health UI maps to Slabi states in [mascot.md](mascot.md) (optional illustration).
- [ ] Do not paste secrets into branded HTML/CSS.

## Authentik / tofu hint

Update `tofu/authentik/brand.tf` — brand fields use **relative** paths under `media/public/` (e.g. `slab/logo-horizontal-dark.png`). K8s ConfigMap `authentik-brand-assets` + server init copies to `/media/public/slab/`. Email HTML uses raw GitHub URLs (Authentik `/media/public/*` is not public in 2025.12+).

## OpenCode / Cursor UI

Inject `tokens.json` `color.light` or `color.dark` into editor themes when user asks for SLAB-styled tools. UI font stack: Inter / system-ui — **not** the custom SLAB wordmark font.

## Generating new art

Prompt anchors for image models:

- Logo: “Geometric purple S with circular network nodes, paired with connected SLAB lettering, dominiksiejak.pl subtext, soft white background #F7F6FA”
- Slabi: “Stylized lavender whippet, slim silhouette, purple collar with tag, glowing violet tail tip, friendly 3D render, **no** letter S on fur”

Save new renders under `assets/mascot-reference/` with descriptive filenames; update [mascot.md](mascot.md) pose table.

## Files map

```
brand/
├── SKILL.md
├── tokens.json
├── tokens.css
├── preview.html
├── logo-spec.md
├── mascot.md
├── layouts.md
└── assets/
    ├── logo-horizontal-light.jpg
    ├── svg/          # icon, banners, wallpapers
    └── mascot-reference/
```
