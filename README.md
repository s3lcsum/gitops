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
  - [Nginx Proxy Manager](https://github.com/NginxProxyManager/nginx-proxy-manager)
  - [Watchtower](https://github.com/containrrr/watchtower)
  - [Upsnap](https://github.com/seriousm4x/UpSnap)
  - [CUPS](https://github.com/OpenPrinting/cups)
  - [Victoria Metrics](https://github.com/VictoriaMetrics/VictoriaMetrics)
  - [Uptime Kuma](https://github.com/louislam/uptime-kuma)
  - [Grafana](https://github.com/grafana/grafana)
  - [Grafana Synthetic Monitoring Agent](https://github.com/grafana/synthetic-monitoring-agent)
  - [MKTXP](https://github.com/akpw/mktxp) (MikroTik Prometheus exporter)
  - [WatchYourLAN](https://github.com/aceberg/WatchYourLAN)
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
│   ├── authentik/              # Single Sign-On & Identity Provider
│   ├── cloudflared/            # Cloudflare Tunnel
│   ├── cups/                   # Print server
│   ├── dozzle/                 # Docker container logs viewer
│   ├── mktxp/                  # MikroTik metrics exporter
│   ├── netbootxyz/             # Network boot utility
│   ├── nginx_proxy_manager/    # Reverse proxy with SSL
│   ├── upsnap/                 # Wake-on-LAN dashboard
│   ├── uptime_kuma/            # Uptime monitoring
│   ├── victoria/               # Metrics database & logs
│   ├── watchtower/             # Automatic container updates
│   └── watchyourlan/           # Network discovery & monitoring
│
└── /terraform/
    ├── authentik/              # Authentik SSO configuration
    ├── portainer/              # Container management platform
    ├── proxmox/                # Hypervisor & container management
    └── routeros/               # Router configuration
```

---

## Changelog

### Current Status (January 2025)

✅ **Major Infrastructure Milestone Achieved**: All planned Portainer stacks have been successfully implemented and are running in production. The homelab now features a complete Infrastructure as Code setup with Terraform managing the entire stack deployment.

**Recent Achievements:**
- ✅ All Docker Compose stacks migrated to dedicated directories with proper configuration
- ✅ Complete Terraform automation for Portainer stack management
- ✅ Added MKTXP for comprehensive MikroTik monitoring
- ✅ Implemented WatchYourLAN for network device discovery
- ✅ Streamlined repository structure for better maintainability

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

### ✅ Completed

- [x] **Portainer's stacks** (All implemented and running):
  - [x] authentik
  - [x] cloudflared
  - [x] cups
  - [x] dozzle
  - [x] mktxp
  - [x] netboot.xyz
  - [x] nginx proxy manager
  - [x] upsnap
  - [x] uptime kuma
  - [x] victoria metrics
  - [x] watchtower
  - [x] watchyourlan

- [x] **Terraform Infrastructure**:
  - [x] **Portainer**: All stacks are deployed and managed via Terraform
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
  - [x] **Proxmox**: Basic LXC container management
    - [x] LXC: Portainer
    - [x] LXC: AdGuard
  - [x] **RouterOS**: Core networking services
    - [x] DNS
    - [x] DHCP
    - [x] NTP

### 🚧 In Progress

- [ ] **Advanced Terraform Configuration**:
  - [ ] Portainer:
    - [ ] Users & Groups management
    - [ ] Advanced host settings
    - [ ] Environment variables & secrets management
  - [ ] Proxmox:
    - [ ] Advanced host settings & templates
    - [ ] VM automation
  - [ ] RouterOS:
    - [ ] Interface management
    - [ ] Firewall rules automation
    - [ ] WireGuard VPN setup
  - [ ] Authentik:
    - [ ] LDAP directory setup
    - [ ] OIDC provider configurations
    - [ ] SAML integration
    - [ ] User and group management

### 📋 Planned

- [ ] **Monitoring & Observability**:
  - [ ] Complete VictoriaMetrics/Logs configuration
    - [ ] Docker container metrics & logs
    - [ ] System metrics (syslog from wally-0)
    - [ ] RouterOS metrics via MKTXP
    - [ ] AdGuard metrics integration
  - [ ] Enhanced Grafana dashboards
  - [ ] Alerting system setup

- [ ] **Infrastructure Expansion**:
  - [ ] Complete Pi-hole to AdGuard migration
  - [ ] Ansible automation:
    - [ ] Proxmox host configuration
    - [ ] AdGuard setup automation
    - [ ] Portainer host defaults
  - [ ] NetBox for network documentation
  - [ ] HomeAssistant integration

- [ ] **Security & Backup**:
  - [ ] Synology NAS integration:
    - [ ] Cloud drive migration
    - [ ] Proxmox backup automation
    - [ ] Authentik LDAP integration
  - [ ] Secrets management (HashiCorp Vault)
  - [ ] Network segmentation (IoT subnets)
  - [ ] UPS/NUT integration

- [ ] **Advanced Features**:
  - [ ] CI/CD pipeline for infrastructure
  - [ ] K3s single-node cluster
  - [ ] Self-hosted LLM (Ollama)
  - [ ] Cloud redundancy (CloudLab instance)
  - [ ] Infrastructure diagram generation

---

## 🚀 Quick Start

### Prerequisites
- Terraform installed
- Access to Proxmox VE
- Portainer running with API access
- MikroTik RouterOS with admin access

### Deployment
```bash
# Clone the repository
git clone <repository-url>
cd homelab

# Deploy infrastructure
cd terraform/portainer
terraform init
terraform apply

# Stacks are automatically deployed via Terraform
```

### Management
- **Portainer**: Managed via Terraform configurations
- **Monitoring**: VictoriaMetrics + Grafana dashboards
- **Access**: Authentik SSO for all services
- **Updates**: Watchtower handles automatic container updates
