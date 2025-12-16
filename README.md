# Home Infrastructure as Code

A reference repository showcasing how I like to manage my home lab infrastructure — treating personal infra with the same rigor you'd expect in a production environment. Everything is versioned, automated where it makes sense, and documented properly.

**What's here:**

- `stacks/` — Docker Compose stacks deployed via Portainer
- `terraform/` — Infrastructure as Code modules for various providers
- `docs/` — ADRs, golden paths, runbooks, playbooks, and architecture diagrams

---

## At a Glance

| Layer | What | Tools |
|-------|------|-------|
| **Compute** | Proxmox VE hosts running LXC containers | Terraform (`terraform/proxmox/`) |
| **Containers** | Docker stacks managed via Portainer | Compose files in `stacks/` |
| **Networking** | MikroTik RouterOS config | Terraform (`terraform/routeros/`) |
| **Edge** | Traefik reverse proxy + CrowdSec | `stacks/traefik/` |
| **Identity** | Authentik (OAuth, SAML, LDAP) | `stacks/authentik/` + Terraform |
| **Inventory** | NetBox for IPAM/DCIM | `stacks/netbox/` + Terraform (`terraform/netbox/`) |
| **Secrets** | HashiCorp Vault + Vaultwarden | `stacks/vault/`, `stacks/vaultwarden/` |
| **Monitoring** | Uptime Kuma, Grafana Synthetic Agent | `stacks/uptime_kuma/`, `stacks/grafana-synthetic-agent/` |
| **Media** | Jellyfin + *arr stack + downloaders | `stacks/mediabox/` |

📖 **[Full documentation](docs/index.md)** — ADRs, golden paths, runbooks, playbooks, and C4 architecture diagrams.

---

## NetBox: Source of Truth

[NetBox](https://github.com/netbox-community/netbox) serves as the single source of truth for infrastructure inventory:

- **What it tracks**: Sites, devices, device types, manufacturers, IP addresses, prefixes, VLANs, tags
- **How it fits**: The `terraform/netbox/` module manages NetBox objects as code, keeping the inventory in sync with reality
- **Access**: Internal only — `https://netbox.your-domain.local` (placeholder)

The Terraform module (`terraform/netbox/`) defines:
- Device roles and types
- Manufacturers
- Sites and locations
- IP prefixes and addresses
- Tags for organization

---

## Services

| Icon | Service | Purpose |
|------|---------|----------|
| <img src="./docs/assets/adguard.png" width="32" height="32"> | [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) | Network-wide DNS + adblocking |
| <img src="./docs/assets/authentik.svg" width="32" height="32"> | [Authentik](https://github.com/goauthentik/authentik) | Identity & Access Management (OAuth, SAML, LDAP) |
| <img src="./docs/assets/bazarr.png" width="32" height="32"> | [Bazarr](https://github.com/morpheus65535/bazarr) | Subtitle automation |
| <img src="./docs/assets/calibre.png" width="32" height="32"> | [Calibre](https://github.com/kovidgoyal/calibre) | eBook management & library |
| <img src="./docs/assets/cloudflare.png" width="32" height="32"> | [Cloudflared](https://github.com/cloudflare/cloudflared) | Tunnel to Cloudflare for remote access |
| <img src="./docs/assets/cups.svg" width="32" height="32"> | [CUPS](https://github.com/OpenPrinting/cups) | Print server |
| <img src="./docs/assets/diun.png" width="32" height="32"> | [DIUN](https://github.com/crazy-max/diun) | Docker image update notifications |
| <img src="./docs/assets/dozzle.svg" width="32" height="32"> | [Dozzle](https://github.com/amir20/dozzle) | Docker container log viewer |
| <img src="./docs/assets/flaresolverr.svg" width="32" height="32"> | [FlareSolverr](https://github.com/FlareSolverr/FlareSolverr) | Cloudflare bypass for indexers |
| <img src="./docs/assets/gluetun.png" width="32" height="32"> | [Gluetun](https://github.com/qdm12/gluetun) | VPN gateway for "download stuff" apps |
| <img src="./docs/assets/grafana.png" width="32" height="32"> | [Grafana Synthetic Agent](https://github.com/grafana/synthetic-monitoring-agent) | Uptime & performance monitoring |
| <img src="./docs/assets/jellyfin.svg" width="32" height="32"> | [Jellyfin](https://github.com/jellyfin/jellyfin) | Media server |
| <img src="./docs/assets/jellyseerr.webp" width="32" height="32"> | [Jellyseerr](https://github.com/Fallenbagel/jellyseerr) | Requests / discovery for Jellyfin |
| <img src="./docs/assets/n8n.png" width="32" height="32"> | [n8n](https://github.com/n8n-io/n8n) | Workflow automation platform |
| <img src="./docs/assets/netbootxyz.png" width="32" height="32"> | [netboot.xyz](https://github.com/netbootxyz/netboot.xyz) | Network boot environments |
| <img src="./docs/assets/netbox.png" width="32" height="32"> | [NetBox](https://github.com/netbox-community/netbox) | Network infrastructure IPAM |
| <img src="./docs/assets/postgresql.jpg" width="32" height="32"> | [PostgreSQL](https://github.com/postgres/postgres) | Database server |
| <img src="./docs/assets/prowlarr.png" width="32" height="32"> | [Prowlarr](https://github.com/Prowlarr/Prowlarr) | Indexer manager |
| <img src="./docs/assets/qbittorrent.png" width="32" height="32"> | [qBittorrent](https://github.com/qbittorrent/qBittorrent) | Torrent client (routed via VPN) |
| <img src="./docs/assets/radarr.png" width="32" height="32"> | [Radarr](https://github.com/Radarr/Radarr) | Movie automation |
| <img src="./docs/assets/sabnzbd.png" width="32" height="32"> | [SABnzbd](https://github.com/sabnzbd/sabnzbd) | Usenet downloader (routed via VPN) |
| <img src="./docs/assets/sonarr.webp" width="32" height="32"> | [Sonarr](https://github.com/Sonarr/Sonarr) | TV automation |
| <img src="./docs/assets/traefik.png" width="32" height="32"> | [Traefik](https://github.com/traefik/traefik) | Reverse proxy with CrowdSec security integration |
| <img src="./docs/assets/upsnap.png" width="32" height="32"> | [Upsnap](https://github.com/seriousm4x/UpSnap) | Wake-on-LAN management |
| <img src="./docs/assets/uptime-kuma.png" width="32" height="32"> | [Uptime Kuma](https://github.com/louislam/uptime-kuma) | Uptime monitoring & status page |
| <img src="./docs/assets/vault.png" width="32" height="32"> | [Vault](https://github.com/hashicorp/vault) | Secrets management |
| <img src="./docs/assets/vaultwarden.png" width="32" height="32"> | [Vaultwarden](https://github.com/dani-garcia/vaultwarden) | Password manager server (Bitwarden compatible) |
| <img src="./docs/assets/warrtracker.png" width="32" height="32"> | [Warrtracker](https://github.com/WarrionerGT/Warrtracker) | Warranty & asset tracking |
| <img src="./docs/assets/watchyourlan.png" width="32" height="32"> | [watchyourlan](https://github.com/aceberg/watchyourlan) | LAN device discovery & monitoring |

---

## Infrastructure Overview

### Network

- **ISP**: INEA (Poland) — 300Mb/s synchronous FTTH
- **Router**: MikroTik hAP ac3
- **Wireless**: TP-Link Deco M4R x3 (mesh)
- **Remote Access**: Public IP with WireGuard / ngrok (backup)

**IP Allocation:**

| Range | Purpose |
|-------|---------|
| `.0–.9` | Network devices |
| `.10–.99` | Static IPs |
| `.100–.199` | DHCP pool |
| `.200–.254` | Homelab interfaces |

DHCP + NTP handled via RouterOS.

### Compute

- **Main Server (lake-1)**: Mini PC FIREBAT T8 Pro Plus — Intel N100, 16GB DDR5, 512GB SSD
  - Runs Proxmox VE
  - Hosts containers and VMs
- **Secondary Server (edge-1)**: Dell PowerEdge R610 (experimental)
  - Runs Proxmox VE
  - Mostly off, sometimes runs a Minecraft server for my brother

**LXC Containers on Proxmox:**

- Docker (Portainer host)
- AdGuard
- HomeAssistant

### Storage

- **NAS**: Synology DS220+ with 2 × 4TB disks
  - Primary storage + backups

### Client Devices

- Apple ecosystem (MacBook, iPhone, iPad, etc.)
- Android devices
- eBook readers (Kobo/Kindle)
- PCs with Windows 11/Fedora
- Samsung TVs
- Raspberry Pi (SDR Radio, 3D Printers)
- Printers: Sharp MX-4071, OKI ES5461

---

## How to Use This Repo

### Terraform Workflow

Each Terraform module under `terraform/` has a `Makefile` with standard targets:

```bash
cd terraform/<module>
make init      # Initialize Terraform
make plan      # Preview changes
make apply     # Apply changes (auto-approve)
make destroy   # Tear down (auto-approve)
make validate  # Validate configuration
make fmt       # Format files
make check     # Run validate + fmt
make clean     # Remove .terraform/ and lock files
```

Some modules have extra targets (e.g., `terraform/portainer/` has `sync-portainer` to rsync stacks to the host).

### Docker Stacks Workflow

Stacks live in `stacks/<service>/` with:

- `compose.yaml` — the Docker Compose file
- `*.env.example` — example environment variables (copy to `*.env` and fill in secrets)
- Optional config files (e.g., `traefik.yaml`, `dynamic.yaml`)

**To deploy a stack:**

1. Copy `*.env.example` to `*.env` and fill in secrets
2. Either:
   - Use Portainer to deploy the stack, or
   - Run `docker compose up -d` directly on the host

The `terraform/portainer/` module handles syncing stacks to the Portainer host via rsync.

### Secrets Handling

- **`.env.example` files**: Committed to the repo — contain structure and placeholder values
- **`.env` files**: Never committed — contain actual secrets (gitignored)
- **Sensitive Terraform variables**: Stored in `defaults.auto.tfvars` or passed via environment

---

## Repository Structure

```
├── docs/                           # Documentation
│   ├── index.md                    # Docs portal
│   ├── adr/                        # Architecture Decision Records
│   ├── golden-paths/               # How-to guides for common tasks
│   ├── runbooks/                   # Incident response procedures
│   ├── playbooks/                  # Repeatable operational tasks
│   ├── architecture/               # C4 diagrams and system overviews
│   └── assets/                     # Icons and images
│
├── stacks/                         # Docker Compose stacks
│   ├── adguard/
│   ├── authentik/
│   ├── calibre/
│   ├── cloudflared/
│   ├── cups/
│   ├── diun/
│   ├── dozzle/
│   ├── grafana-synthetic-agent/
│   ├── mediabox/
│   ├── n8n/
│   ├── netbootxyz/
│   ├── netbox/
│   ├── postgres/
│   ├── traefik/
│   ├── upsnap/
│   ├── uptime_kuma/
│   ├── vault/
│   ├── vaultwarden/
│   ├── warrtracker/
│   └── watchyourlan/
│
├── terraform/                      # Infrastructure as Code
│   ├── authentik/
│   ├── backblaze/
│   ├── gcp/
│   ├── netbox/
│   ├── portainer/
│   ├── proxmox/
│   ├── routeros/
│   ├── synology-nas/
│   └── terraform-cloud/
│
├── mkdocs.yml                      # MkDocs configuration
└── README.md
```

---

## Roadmap

- [x] Portainer stacks:
  - [x] authentik
  - [x] cloudflared
  - [x] cups
  - [x] dozzle
  - [x] grafana-synthetic-agent
  - [x] mediabox
  - [x] n8n
  - [x] netboot.xyz
  - [x] postgres
  - [x] traefik
  - [x] upsnap
  - [x] uptime kuma
  - [x] watchyourlan
- [ ] Terraform:
  - [ ] Portainer:
    - [x] All stacks created
    - [ ] Users & Groups
    - [ ] Host Settings
  - [ ] Proxmox:
    - [ ] Host settings
    - [x] LXC: Portainer
    - [x] LXC: AdGuard
  - [ ] RouterOS:
    - [ ] Interfaces
    - [ ] Firewall rules
    - [x] DNS
    - [x] DHCP
    - [x] NTP
    - [ ] WireGuard
  - [ ] Authentik:
    - [ ] General settings
    - [ ] LDAP setup
    - [ ] OIDC providers
    - [ ] SAML integration
    - [ ] Groups and users
- [ ] Future:
  - [ ] Ansible playbooks for host configuration
  - [ ] Migrate cloud drives to NAS
  - [ ] Migrate backups from Proxmox to NAS
  - [ ] Use Authentik LDAP for Synology
  - [ ] Add NUT/UPS integration
  - [ ] k3s single-node cluster
  - [ ] Self-hosted LLM (Ollama)
  - [ ] Separated subnets (IoT isolation)

---

## Changelog

### 16.12.2025

README cleanup: the "Apps on Portainer" table now actually lists everything that's sitting in `stacks/` (adguard/keycloak/openldap included). Also expanded the whole mediabox setup into the individual apps (Jellyfin, *arrs, downloaders, VPN gateway), so it's not a mystery box anymore. Pulled proper icons into `docs/assets/` for the mediabox apps too (incl. FlareSolverr) — README is now local-images-only.

### 15.12.2025

Ripped out ZITADEL and went back to Authentik after realizing it was just causing more headaches than it was worth. Re-added Authentik service with full Docker Compose setup, updated PostgreSQL config to handle Authentik DB creds properly, and cleaned up all the ZITADEL cruft from Terraform. Also added Diun for Docker image update notifications. Basically reverting back to what was working before.

### 23.11.2025

Wrote up new repo rules for Docker Compose stacks and Terraform/GCP configs, gutted the unused ArgoCD/Cert-Manager/chart cruft, and rewired the mediabox/Traefik/Portainer pieces: Configarr is gone, Vaultwarden got its own stack plus DB creds, and Terraform-side references now match the fresh stack layout. Lost some commits while switching PCs before I could push them (the HDD format nuked the old machine), so this is the history that actually made it up here.

### 23.08.2025

Swapped Authentik with ZITADEL due to ongoing configuration issues. Despite limited documentation for ZITADEL, it's an actively growing project with promising potential.

### 22.08.2025

Switched back from Podman to Docker due to too many compatibility issues. Docker has better ecosystem support and fewer configuration headaches.

### 20.08.2025

Upgraded hardware by replacing old wally-1 terminal with new lake-1 server (Mini PC FIREBAT T8 Pro Plus Intel N100 16GB DDR5 / 512GB) for better performance. Also migrated domain from wally.dominiksiejak.pl to lake.dominiksiejak.pl, updating 25+ configuration files across Docker stacks, Helm charts, and Terraform modules. Updated all Traefik routing, SSL certificates, DNS, and service URLs.

### 31.07.2025

Major infrastructure improvements: added n8n for workflow automation, PostgreSQL for database storage, and Grafana Synthetic Monitoring Agent. Enhanced development tools with pre-commit hooks, GitHub Actions, and improved CI/CD pipeline. Improved Traefik routing and security, updated Docker images, added healthchecks. Removed mktxp stack and .cursorrules file. Updated various configurations and documentation.

### 7.07.2025

Replaced Nginx Proxy Manager with Traefik as the reverse proxy and added CrowdSec security integration. Added mediabox stack for home media server setup. Removed VictoriaMetrics stack since moving to Grafana Cloud. Updated all stack configurations to use Traefik labels.

### 25.05.2025

Refactored the Terraform code slightly to reduce repetition. I also removed 'watchtower' — it's a great tool, but I prefer to update everything manually, and RenovateBot will handle the rest.

### 21.05.2025

I have configured the Google SSO for Authentik with the terraform. However, I did some changes manually in the UI for the flows/stages, as they're super difficult to configure via terraform.

### 20.05.2025

I have just refactored Portainer stacks, so I won't have to deal with many resources, but have done it all in a single array. Before, I thought it would be better this way, but it wasn't worth it.

### 18.05.2025

I'm reverting from Portainer's GitOps option that was automatically pulling stacks from this repository. The delay between commits and actual changes in Portainer was frustrating. Plus, I couldn't make any temporary changes in stacks. I'd rather execute `terraform apply` to keep everything in one place.

### 17.05.2025

Because I accidentally deleted my authentik environment variables, I decided to give authelia a shot. I've heard only good things about it, and it's fully configurable via YAML files. It seemed promising, but I felt like I was missing some options that worked perfectly out-of-the-box in authentik. I tried to configure it, but ended up restoring authentik from backup anyway.
