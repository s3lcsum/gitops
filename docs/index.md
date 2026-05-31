# GitOps

Documentation for this repo — smaller on purpose than the README when you need a **published** site (`mkdocs serve` / GitHub Pages).

## Networking

- **[Homelab subnets and addressing](networking/homelab-subnets.md)** — IPv4 LAN, IPv6 ULAs (Talos pods/services), and where the same data lives in Terraform + NetBox.

## Architecture decisions

- **[ADR001: Traefik over NPM](adr/adr001-traefik-over-npm.md)**
- **[ADR002: Authentik over ZITADEL](adr/adr002-authentik-over-zitadel.md)**

## Golden paths

- **[GP001: Add Docker stack](golden-paths/gp001-add-docker-stack.md)**
- **[GP002: Add Terraform module (Gitea mirrors)](golden-paths/gp002-add-terraform-module-gitea-mirrors.md)

## Runbooks

- **[RB001: Initialize Vault](runbooks/rb001-initialize-vault.md)**

## What’s not here

- **Docker stack catalog** — see the README’s *Services* section (kept in sync with `terraform/portainer/locals.tf`).
- **Kubernetes / Talos app list** — not documented in MkDocs; those workloads moved off several legacy Compose stacks (see README changelog **6.04.2026**).
