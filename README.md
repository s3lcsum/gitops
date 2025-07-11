# 🏠 Welcome in my Home(Lab)

This repository contains all configuration and documentation for my hobbist
homelab setup.

The goal is to track infrastructure changes, automate as much as possible, and
provide a living reference for improvements. Contributions and suggestions are welcome.

---

## 🌐 Infrastructure Overview

- **Network Provider**: INEA (Poland) 300Mb/s synchronous FTTH

- **Router**: MikroTik hAP ac3

- **Main Server (wally-1)**: Dell Wyse thin client
  - Runs **Proxmox VE**
  - Hosts containers and VMs

- **Secondary Server (edge-1)**: Dell PowerEdge R610 (experimental)
  - Runs **Proxmox VE**
  - Mostly it's turned off, sometimes runs a Minecraft server for my brother

- **NAS**: Synology, 2 × 4TB disks
  - Storage + backups

- **LXC Containers (on Proxmox):**
  - Docker/Portainer
  - Pi-hole (deprecating)
  - AdGuard

- **Apps on Portainer:**
  - [authentik](https://github.com/goauthentik/authentik)
  - [cloudflared](https://github.com/cloudflare/cloudflared)
  - [dozzle](https://github.com/amir20/dozzle)
  - [netboot.xyz](https://github.com/netbootxyz/netboot.xyz)
  - [Traefik](https://github.com/traefik/traefik) (reverse proxy with CrowdSec security)
  - [Upsnap](https://github.com/seriousm4x/UpSnap)
  - [CUPS](https://github.com/OpenPrinting/cups)
  - [Uptime Kuma](https://github.com/louislam/uptime-kuma)
  - [mktxp](https://github.com/akpw/mktxp)
  - [watchyourlan](https://github.com/aceberg/watchyourlan)
  - [alloy](https://github.com/grafana/alloy) (Grafana Alloy agent for logs/metrics)
  - mediabox (qBittorrent, Sonarr, Radarr, Jellyfin, etc. - media automation stack)
  - [Grafana](https://github.com/grafana/grafana)
  - [Grafana Synthetic Monitoring Agent](https://github.com/grafana/synthetic-monitoring-agent)
    (I'm using Grafana Cloud for synthetic checks)

- **Networking:**
  - IP Ranges:
    - `.0-.9`: network devices
    - `.10-.99`: static IPs
    - `.100-.199`: DHCP
    - `.200-.254`: Homelab interfaces
  - DHCP + NTP handled via RouterOS
  - Remote Access: Tailscale / ngrok (as backup, when accidentally kill tailscale)
  - Wireless: TP-Link Deco x3

- **Client Devices:**
  - Apple ecosystem (MacBook, iPhone, iPad, etc.)
  - Android devices
  - ebook readers (kobo/kindle)
  - PCs with Windows 11/Fedora
  - TVs with Samsung
  - Raspberry Pi
    - SDR Radio
    - 3D Printers
  - Printers:
    - Sharp MX-4071
    - OKI ES5461

---

## 📁 Repository Structure

```
├── /stacks/
│   ├── alloy/                # Grafana Alloy agent
│   ├── authentik/            # Authentik SSO
│   ├── cloudflared/          # Cloudflare Tunnel
│   ├── cups/                 # CUPS print server
│   ├── dozzle/               # Dozzle log viewer
│   ├── mediabox/             # Media automation stack (qBittorrent, Sonarr, Radarr, Jellyfin, etc.)
│   ├── mktxp/                # Mikrotik Prometheus exporter
│   ├── netbootxyz/           # Netboot.xyz PXE
│   ├── traefik/              # Traefik reverse proxy with CrowdSec security
│   ├── upsnap/               # Upsnap wake-on-LAN
│   ├── uptime_kuma/          # Uptime Kuma monitoring
│   └── watchyourlan/         # WatchYourLAN network scanner
│
└── /terraform/
    ├── authentik/            # Authentik SSO infra
    ├── portainer/            # Portainer infra
    ├── proxmox/              # Proxmox infra
    └── routeros/             # RouterOS infra
```

---

## Changelog

### 7.07.2025

Major infrastructure changes:
- Replaced Nginx Proxy Manager with **Traefik** as the reverse proxy
- Added **CrowdSec** security integration with Traefik
- Added **mediabox** stack to start fun with home media server
- Removed VictoriaMetrics stack (moved to Grafana Cloud)
- Updated all stack configurations to use Traefik labels

### 25.05.2025

Refactored the Terraform code slightly to reduce repetition. I also removed
'watchtower' —it's a great tool, but I prefer to update everything manually,
and RenovateBot will handle the rest.

### 21.05.2025

I have configured the Google SSO for Authentik with the terraform. However, I
did some changes manually in the UI for the flows/stages, as they're super
difficult to configure via terraform.

### 20.05.2025

I have just refactored Portainer stacks, so I won't have to deal with many
resources, but have done it all in a single array. Before, I thought it would
be better this way, but it wasn't worth it.

### 18.05.2025

I'm reverting from Portainer's GitOps option that was automatically pulling
stacks from this repository. The delay between commits and actual changes in
Portainer was frustrating. Plus, I couldn't make any temporary changes in
stacks. I'd rather execute `terraform apply` to keep everything in one place.

### 17.05.2025

Because I accidentally deleted my authentik environment variables, I decided to
give authelia a shot. I've heard only good things about it, and it's fully
configurable via YAML files. It seemed promising, but I felt like I was missing
some options that worked perfectly out-of-the-box in authentik. I tried to
configure it, but ended up restoring authentik from backup anyway.

## 🧭 Roadmap

- [x] Portainer's stacks:
  - [x] authentik
  - [x] cloudflared
  - [x] cups
  - [x] dozzle
  - [x] mktxp
  - [x] netboot.xyz
  - [x] traefik (replaced nginx proxy manager)
  - [x] upsnap
  - [x] uptime kuma
  - [x] watchyourlan
<<<<<<< Updated upstream
  - [x] alloy
  - [x] mediabox
  - [ ] Terraform
    - [ ] Portainer:
      - [x] stack_authentik
      - [x] stack_cloudflared
      - [x] stack_cups
      - [x] stack_mktxp
      - [x] stack_dozzle
      - [x] stack_netbootxyz
      - [x] stack_traefik
      - [x] stack_upsnap
      - [x] stack_uptime_kuma
      - [x] stack_watchyourlan
      - [x] stack_alloy
      - [x] stack_mediabox
        > All stacks are created but some still miss advanced configuration
        > (env variables, secrets, etc.)
      - [ ] Users & Groups
      - [ ] Host Settings
||||||| Stash base
- [ ] Terraform
  - [ ] Portainer:
    - [x] stack_authentik
    - [x] stack_cloudflared
    - [x] stack_cups
    - [x] stack_mktxmp
    - [x] stack_watchtower
    - [x] stack_dozzle
    - [x] stack_netbootxyz
    - [x] stack_nginx_proxy_manager
    - [x] stack_upsnap
    - [x] stack_uptime_kuma
    - [x] stack_victoria
    - [x] stack_watchyourlan
      > All stacks are created but some still miss advanced configuration
      > (env variables, secrets, etc.)
    - [ ] Users & Groups
    - [ ] Host Settings
=======
- [ ] Terraform
  - [ ] Portainer:
    - [x] stack_authentik
    - [x] stack_cloudflared
    - [x] stack_cups
    - [x] stack_mktxmp
    - [x] stack_watchtower
    - [x] stack_dozzle
    - [x] stack_netbootxyz
    - [x] stack_nginx_proxy_manager
    - [x] stack_upsnap
    - [x] stack_uptime_kuma
    - [x] stack_victoria
    - [x] stack_watchyourlan
      > All stacks are created but some still miss advanced configuration
      > (env variables, secrets, etc.)
    - [x] ~Users & Groups~
    - [x] Host Settings (just oAuth)
>>>>>>> Stashed changes
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
  - [ ] VictoriaMetrics/Logs
    - [ ] configure that all possbile metrics and logs are collected via victoria (even if disabled as default;
          `cadvisor` you little spammer I'm looking at you)
    - [ ] docker logs
    - [ ] grafana
    - [ ] syslog (wally-0)
    - [ ] routerOS (use mktxp for exporter)
    - [ ] adguard
  - [ ] finish pi-hole to adgurad migration
  - [ ] Ansible
    - [ ] wally-0 (installing proxmox and other simple host configuration)
    - [ ] adguard configuration (but consider cloud-init instead)
    - [ ] portainer host default configuration
  - [ ] setup NetBox (so whole network infrastructure wil be saved in one place,
        use terraform/ansible/yaml)
  - [ ] setup HomeAssistant (it's not here, as after I have moved out from home,
         never used it again)
  - [ ] Synology NAS:
    - [ ] Migrate cloud drives to NAS
    - [ ] Migrate backups from Proxmox to NAS
    - [ ] Use Authentik LDAP for Synology
  - [ ] Secrets Management (consider using hashicorp vault or any alternative)
  - [ ] Add NUT/UPS integration
  - [ ] CI/CD pipeline
  - [ ] k3s single-node cluster
  - [ ] Self-hosted LLM (Ollama)
  - [ ] Create Cloud VM instance for CloudLab (for redundancy, nice to have
        some services deployed online, right?)
  - [ ] Use separated subnets (create serveral subnets, so IoT devices will never have access to PC or phones)
  - [ ] Create diagram of the HomeLab Infrastructure
