# C4 Container Diagram

This diagram shows the major containers (applications/services) in the home lab infrastructure and how they communicate.

## Overview Diagram

```mermaid
flowchart TB
    subgraph external [External]
        Internet([Internet])
        CloudflareZT[Cloudflare Zero Trust]
        GrafanaCloud[Grafana Cloud]
        LetsEncrypt[Let's Encrypt]
    end

    subgraph network [Network Layer]
        Router[MikroTik Router<br/>RouterOS]
        WireGuard[WireGuard VPN]
        AdGuard[AdGuard Home<br/>DNS + Adblock]
    end

    subgraph proxmox [Proxmox VE - lake-1]
        subgraph docker [Docker Host - Portainer]
            Traefik[Traefik<br/>Reverse Proxy]
            CrowdSec[CrowdSec<br/>Security]
            
            subgraph identity [Identity]
                Authentik[Authentik<br/>IdP]
            end

            subgraph data [Data Layer]
                PostgreSQL[(PostgreSQL)]
                Vault[HashiCorp Vault<br/>Secrets]
                Vaultwarden[Vaultwarden<br/>Passwords]
            end

            subgraph infra [Infrastructure]
                NetBox[NetBox<br/>IPAM/DCIM]
                UptimeKuma[Uptime Kuma<br/>Monitoring]
                N8N[n8n<br/>Automation]
                Dozzle[Dozzle<br/>Logs]
            end

            subgraph media [Media Stack]
                Jellyfin[Jellyfin<br/>Media Server]
                Sonarr[Sonarr<br/>TV]
                Radarr[Radarr<br/>Movies]
                Prowlarr[Prowlarr<br/>Indexers]
                Gluetun[Gluetun<br/>VPN Gateway]
                QBittorrent[qBittorrent]
                SABnzbd[SABnzbd]
            end
        end

        HomeAssistant[Home Assistant<br/>LXC]
    end

    subgraph storage [Storage]
        SynologyNAS[(Synology NAS<br/>4TB x2)]
    end

    subgraph terraform [Terraform Management]
        TFCloud[Terraform Cloud]
        TFProviders[Providers:<br/>Proxmox, RouterOS,<br/>Authentik, NetBox,<br/>Backblaze, GCP]
    end

    %% External connections
    Internet -->|HTTPS| CloudflareZT
    CloudflareZT -->|Tunnel| Traefik
    Internet -->|WireGuard| WireGuard
    WireGuard --> Router
    LetsEncrypt -->|ACME| Traefik
    UptimeKuma -->|Metrics| GrafanaCloud

    %% Network flow
    Router --> AdGuard
    AdGuard -->|DNS| docker

    %% Traefik routing
    Traefik --> CrowdSec
    Traefik -->|Forward Auth| Authentik
    Traefik --> Jellyfin
    Traefik --> NetBox
    Traefik --> N8N
    Traefik --> Vaultwarden
    Traefik --> UptimeKuma
    Traefik --> Dozzle

    %% Database connections
    Authentik --> PostgreSQL
    NetBox --> PostgreSQL
    N8N --> PostgreSQL

    %% Media stack
    Sonarr --> Prowlarr
    Radarr --> Prowlarr
    Sonarr --> QBittorrent
    Sonarr --> SABnzbd
    Radarr --> QBittorrent
    Radarr --> SABnzbd
    QBittorrent --> Gluetun
    SABnzbd --> Gluetun
    Gluetun -->|VPN| Internet
    Jellyfin --> SynologyNAS

    %% Storage
    media --> SynologyNAS

    %% Terraform
    TFCloud --> TFProviders
    TFProviders -.->|Manages| Router
    TFProviders -.->|Manages| Authentik
    TFProviders -.->|Manages| NetBox
    TFProviders -.->|Manages| proxmox
```

## Component Descriptions

### Edge Layer

| Component | Purpose | Managed By |
|-----------|---------|------------|
| **Cloudflare Zero Trust** | Secure tunnel for external access without exposing ports | Cloudflare dashboard |
| **Traefik** | Reverse proxy, SSL termination, routing | `stacks/traefik/` |
| **CrowdSec** | Threat detection and blocking | `stacks/traefik/` |
| **WireGuard** | VPN for direct access when needed | RouterOS |

### Identity & Security

| Component | Purpose | Managed By |
|-----------|---------|------------|
| **Authentik** | Single sign-on, OAuth/OIDC, LDAP | `stacks/authentik/`, `terraform/authentik/` |
| **Vault** | Secrets management | `stacks/vault/` |
| **Vaultwarden** | Password manager (Bitwarden API) | `stacks/vaultwarden/` |

### Data Layer

| Component | Purpose | Managed By |
|-----------|---------|------------|
| **PostgreSQL** | Shared database for Authentik, NetBox, n8n | `stacks/postgres/` |
| **Synology NAS** | File storage, backups, media | `terraform/synology-nas/` |

### Infrastructure Services

| Component | Purpose | Managed By |
|-----------|---------|------------|
| **NetBox** | IPAM, DCIM, inventory | `stacks/netbox/`, `terraform/netbox/` |
| **Uptime Kuma** | Availability monitoring | `stacks/uptime_kuma/` |
| **n8n** | Workflow automation | `stacks/n8n/` |
| **Dozzle** | Container log viewer | `stacks/dozzle/` |
| **AdGuard Home** | DNS server, ad blocking | LXC container |

### Media Stack

| Component | Purpose | Managed By |
|-----------|---------|------------|
| **Jellyfin** | Media server | `stacks/mediabox/` |
| **Sonarr/Radarr** | TV/Movie automation | `stacks/mediabox/` |
| **Prowlarr** | Indexer management | `stacks/mediabox/` |
| **Gluetun** | VPN gateway for downloaders | `stacks/mediabox/` |
| **qBittorrent/SABnzbd** | Download clients | `stacks/mediabox/` |

### Network Layer

| Component | Purpose | Managed By |
|-----------|---------|------------|
| **MikroTik Router** | Routing, firewall, DHCP, NTP | `terraform/routeros/` |
| **TP-Link Deco** | Wireless mesh | Manual |

## Data Flows

### External Access Flow

```
User → Cloudflare → Cloudflare Tunnel → Traefik → Service
                                           ↓
                                    (Optional: Authentik forward auth)
```

### Media Request Flow

```
User → Jellyseerr → Sonarr/Radarr → Prowlarr → Indexers
                         ↓
              qBittorrent/SABnzbd → Gluetun → VPN → Internet
                         ↓
                   Synology NAS
                         ↓
                     Jellyfin → User
```

### Terraform Management Flow

```
terraform/
    ├── terraform-cloud/  → Manages workspaces
    ├── proxmox/          → Manages VMs/LXCs
    ├── routeros/         → Manages router config
    ├── authentik/        → Manages IdP config
    ├── netbox/           → Manages inventory
    ├── portainer/        → Syncs stacks to host
    └── ...
```

