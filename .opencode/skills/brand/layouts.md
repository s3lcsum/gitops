# Layout exports

Render from SVG or upscale raster. Safe zone = 5% inset from edges.

| Asset | Canvas | Primary file | Notes |
|-------|--------|--------------|-------|
| Favicon | 32×32, 48×48 | `png/mark-32.png`, `mark-64.png` | Primary |
| Square tile | 512×512 | `png/mark-512.png` on `#F9F8FD` | Same mark as favicon |
| Horizontal (dark bg) | — | `png/logo-horizontal-dark.png` | Authentik login logo, email header |
| Mark icon (dark bg) | — | `png/mark-icon.png` | Favicon source, app icon |
| Horizontal (light bg) | 1200×280 approx | `logo-horizontal-light.jpg`, `png/lockup-horizontal-1200.png` | Legacy raster |
| Mark vector | — | pending hand trace | SVG = raster embed today |
| Vertical banner | 1080×1920 | `svg/logo-vertical-light.svg` | Phone wallpaper, story format |
| Vertical narrow | 480×720 | same viewBox | Slack / Discord status |
| Wide banner | 1920×480 | `svg/banner-wide.svg` | Legacy flow bg |
| Flow background | 16∶9 raster | `jpg/slabi-flow-lilac.jpg` | **Authentik** login / recovery flows (deployed via k8s) |
| NAS login / desktop | 16∶9 raster | `nas/dsm-*.jpg` | **Synology DSM** — manual upload, see [nas/README.md](nas/README.md) |
| Wide ultra | 2400×600 | scale banner-wide | Ultrawide login |
| Wallpaper | 3840×2160 | `svg/wallpaper-*.svg` | Desktop |
| Wallpaper 5K | 5120×2880 | scale wallpaper | Optional export |

## GitOps copy

Deployable copies live in repo: `gitops/brand/assets/` (sync with skill `assets/` when updating).

## Authentik (tofu + k8s)

- `tofu/authentik/brand.tf` → `logo-horizontal-dark.png`, `mark-icon.png`
- `kubernetes/platform/authentik/resources/brand-assets/` → PNGs + `slabi-flow-lilac.jpg` via ConfigMap
- `tofu/authentik/brand.tf` → `branding_default_flow_background` + `slab-theme.css` `--ak-flow-background`

## Homepage / Dashy

Use square icon URL + `--slab-brand` CSS variables from `tokens.css`.
