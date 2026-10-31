# Image / chart / provider bump — 2026-10-31

## Goal

Bump every pinned container image, Helm chart, and OpenTofu provider to newest stable. Git-only; no Terrakube apply / Argo force-sync.

## Holds

| Pin | Rule |
|-----|------|
| `mongo:7.0.x` | Latest 7.0.x only — never 8+ (Proxmox kernel ≥6.19 / SERVER-121912) |
| `sure:stable@sha256:…` | Digest pin unchanged |
| `grafana/pdc-agent:latest` | Leave `:latest` |
| `kube-proxy` | Match live cluster Kubernetes minor (`k8s@lake` = v1.37.1) |
| Traefik CrowdSec plugin | Not a container image — leave unless chart requires bump |
| Authentik | Keep server / ldap / radius images + `goauthentik/authentik` provider on same calendar train (`2026.8.x`). Images may track patch ahead of provider when registry lags (images `2026.8.5`, provider latest `2026.8.0`). |

## Procedure

1. Discover newest stable tags (skip `-rc` / `nightly` / `dev`).
2. Edit manifests, ApplicationSet `values.yaml` chart versions, Argo CD bootstrap pins, `providers.tf`.
3. `tofu init -upgrade` per active module (skip `terraform/postgres` apply).
4. Record old → new summary.

## Out of scope

New apps, hold removals, postgres apply, Portainer resurrection.
