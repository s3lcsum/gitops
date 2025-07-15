# RouterOS Terraform Configuration

This directory contains a comprehensive Terraform configuration for managing a MikroTik RouterOS device in a homelab environment.

## 📁 File Structure

```
terraform/routeros/
├── README.md           # This documentation
├── main.tf            # Provider configuration and Terraform settings
├── variables.tf       # All configuration variables
├── system.tf          # System-level configuration (users, NTP, logging, SNMP)
├── interfaces.tf      # Network interfaces, bridge, and interface lists
├── dhcp.tf           # DHCP server, IP pools, and static reservations
├── dns.tf            # DNS configuration (AdGuard integration)
├── firewall.tf       # Comprehensive firewall rules and NAT
├── ddns.tf           # Dynamic DNS for Cloudflare integration
└── wireguard.tf      # WireGuard VPN mesh network configuration
```

## 🔧 Configuration Overview

### System Configuration (`system.tf`)
- **System Identity**: Router hostname
- **Users**: Admin, metrics (read-only), and backup users
- **NTP Client**: Time synchronization with Polish NTP servers
- **Logging**: System logging configuration
- **SNMP**: Metrics collection support
- **Clock**: Timezone configuration

### Network Interfaces (`interfaces.tf`)
- **Bridge**: Main LAN bridge connecting all LAN ports
- **Bridge Ports**: Physical ethernet and wireless interfaces
- **IP Addressing**: Gateway IP configuration
- **DNS**: DNS server configuration
- **Interface Lists**: WAN and LAN interface categorization

### DHCP Configuration (`dhcp.tf`)
- **IP Pool**: Dynamic IP range (192.168.89.100-199)
- **DHCP Server**: Main DHCP service configuration
- **Static Reservations**: Fixed IPs for servers and infrastructure
- **Network Configuration**: Gateway, DNS, and domain settings

### DNS Records (`dns.tf`)
- **Infrastructure**: Router and gateway records
- **Servers**: Proxmox hosts (wally-1, edge-1)
- **Storage**: Synology NAS records
- **Services**: AdGuard, Portainer, Traefik, etc.
- **Applications**: Homarr, Grafana, Jellyfin, etc.
- **Development**: Test, dev, and staging environments
- **Wildcard**: Catch-all subdomain resolution

### Firewall Rules (`firewall.tf`)
- **Input Chain**: Comprehensive input filtering
- **Forward Chain**: Traffic forwarding rules
- **NAT**: Source NAT for internet access
- **Security**: Rate limiting, blacklisting, and logging
- **Services**: SSH, HTTP/HTTPS, DNS, DHCP, NTP, SNMP, Winbox access

### Dynamic DNS (`ddns.tf`)
- **Cloudflare Integration**: Updates DNS records when public IP changes
- **IP Monitoring**: Monitors ether1 interface for IP changes
- **Automatic Updates**: Scheduled checks every 5 minutes
- **Fallback Detection**: Uses external service if interface IP unavailable
- **Conditional Deployment**: Only enabled when `enable_ddns = true`

### WireGuard VPN (`wireguard.tf`)
- **Mesh Network**: Creates secure tunnels between multiple sites
- **Multi-Site Connectivity**: Connects homelab locations and cloud infrastructure
- **Interface Management**: WireGuard interface with proper IP addressing
- **Peer Configuration**: Automated peer setup with public keys and endpoints
- **Routing**: Static routes for remote networks via WireGuard tunnels
- **Firewall Integration**: Comprehensive firewall rules for VPN traffic
- **Conditional Deployment**: Only enabled when `enable_wireguard = true`

## 🌐 Network Layout

```
Network: 192.168.89.0/24
Gateway: 192.168.89.1

IP Ranges:
├── .0-.9      → Network infrastructure devices
├── .10-.99    → Static IP reservations
├── .100-.199  → DHCP lease pool for clients
└── .200-.254  → HomeLab interfaces

Key Devices:
├── 192.168.89.1   → MikroTik hAP ac³ Router/Gateway
├── 192.168.89.11  → edge-1 (Dell PowerEdge R610)
├── 192.168.89.20  → Synology NAS (2×4TB)
├── 192.168.89.30-32 → TP-Link Deco (3× units with ethernet backhaul)
├── 192.168.89.40  → Raspberry Pi (SDR Radio, 3D Printer control)
└── 192.168.89.251 → AdGuard DNS
├── 192.168.89.253 → Docker/Portainer host
├── 192.168.89.254 → wally/wally-0 (Dell Wyse - Main Proxmox)
```

## 🔐 Security Features

### Firewall Protection
- **Input Filtering**: Only allow necessary services from LAN
- **Forward Filtering**: Control traffic between networks
- **Rate Limiting**: SSH brute-force protection
- **Logging**: Comprehensive security event logging
- **Address Lists**: IP whitelisting and blacklisting

### Access Control
- **SSH**: LAN-only access with rate limiting
- **Web Management**: HTTP/HTTPS from LAN only
- **Winbox**: MikroTik management tool access
- **SNMP**: Restricted to metrics collection hosts

### Users and Authentication
- **admin**: Full administrative access
- **metrics**: Read-only access for monitoring systems
- **backup**: Read-only access for backup operations

## 📊 Monitoring and Metrics

### SNMP Configuration
- **Community**: `public` (read-only)
- **Access**: Limited to specific hosts (wally, edge-1)
- **Purpose**: RouterOS metrics collection for Grafana

### Logging
- **Topics**: Info, Error, Warning
- **Storage**: Memory-based logging
- **Security**: Firewall drop events logged

## 🌐 Dynamic DNS (DDNS)

### Cloudflare DDNS Configuration
The RouterOS configuration includes automatic Dynamic DNS functionality for Cloudflare:

- **Automatic IP Detection**: Monitors public IP on ether1 interface
- **Change Detection**: Only updates DNS when IP actually changes
- **Scheduled Updates**: Runs every 5 minutes by default
- **Fallback Method**: Uses external service if interface IP unavailable
- **Multiple Records**: Can update multiple DNS records simultaneously

### Prerequisites
1. **Cloudflare Account**: With domain managed by Cloudflare
2. **API Token**: Create a token with DNS edit permissions
3. **Zone ID**: Get the Zone ID from your Cloudflare dashboard
4. **Existing DNS Records**: Records must already exist in Cloudflare

### Configuration
Enable DDNS by setting the following variables:

```hcl
# Enable DDNS functionality
enable_ddns = true

# Cloudflare credentials (keep these secure!)
cloudflare_api_token = "your-cloudflare-api-token"
cloudflare_zone_id   = "your-zone-id"

# DNS records to update (optional - defaults to home.dominiksiejak.pl)
cloudflare_dns_records = [
  {
    name = "home.yourdomain.com"
    type = "A"
  },
  {
    name = "vpn.yourdomain.com"
    type = "A"
  }
]
```

### How It Works
1. **IP Monitoring**: Script checks ether1 interface for current public IP
2. **Change Detection**: Compares current IP with previously stored IP
3. **DNS Update**: If IP changed, updates specified Cloudflare DNS records
4. **Logging**: All activities logged to RouterOS system log
5. **Scheduling**: Runs automatically every 5 minutes via system scheduler

### Monitoring DDNS
Check DDNS status in RouterOS:
```
# View system logs for DDNS activity
/log print where topics~"info" and message~"DDNS"

# Check if scripts are installed
/system script print

# Check scheduler status
/system scheduler print
```

### Troubleshooting
- **No IP Changes**: Check if ether1 has dynamic IP address
- **API Errors**: Verify Cloudflare API token and zone ID
- **DNS Not Updating**: Ensure DNS records exist in Cloudflare first
- **Script Errors**: Check RouterOS system logs for detailed error messages

## 🔗 WireGuard VPN Mesh Network

### Overview
The RouterOS configuration includes comprehensive WireGuard VPN support for creating a secure mesh network between multiple homelab sites and cloud infrastructure. This enables seamless connectivity between different locations while maintaining security and performance.

### Network Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                    WireGuard Mesh Network                       │
│                      10.100.0.0/24                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Site 1 (Current)           Site 2 (Remote House)              │
│  ┌─────────────────┐        ┌─────────────────┐                │
│  │ 192.168.89.0/24 │◄──────►│ 192.168.90.0/24 │                │
│  │ WG: 10.100.0.1  │        │ WG: 10.100.0.2  │                │
│  └─────────────────┘        └─────────────────┘                │
│           │                           │                         │
│           └─────────────┬─────────────┘                         │
│                         │                                       │
│                         ▼                                       │
│                ┌─────────────────┐                              │
│                │ Cloud Infrastructure │                         │
│                │   10.0.0.0/16   │                              │
│                │ WG: 10.100.0.10 │                              │
│                └─────────────────┘                              │
└─────────────────────────────────────────────────────────────────┘
```

### Key Features
- **Multi-Site Connectivity**: Secure tunnels between homelab locations
- **Cloud Integration**: Connect to cloud infrastructure (VPS, cloud providers)
- **Mesh Topology**: Full connectivity between all sites
- **Automatic Routing**: Static routes for seamless network access
- **Firewall Integration**: Comprehensive security rules for VPN traffic
- **NAT Support**: Optional internet access for remote sites through main location

### Configuration

#### Prerequisites
1. **WireGuard Keys**: Generate public/private key pairs for each site
2. **Network Planning**: Assign unique IP ranges for each site
3. **Firewall Rules**: Ensure WireGuard ports are accessible
4. **DNS Configuration**: Optional DNS forwarding for remote sites

#### Generate WireGuard Keys
```bash
# Generate private key
wg genkey > private.key

# Generate public key from private key
wg pubkey < private.key > public.key
```

#### Enable WireGuard
Set the following variables in your terraform configuration:

```hcl
# Enable WireGuard functionality
enable_wireguard = true

# WireGuard interface configuration
wireguard_listen_port = 51820
wireguard_private_key = "your-private-key-here"
wireguard_local_ip    = "10.100.0.1"

# Peer configurations
wireguard_peers = {
  "house-2" = {
    public_key           = "peer-public-key-here"
    endpoint             = "remote-house-ip:51820"
    allowed_ips          = ["10.100.0.2/32", "192.168.90.0/24"]
    comment              = "Second house location"
    persistent_keepalive = 25
  }
  "cloud-infra" = {
    public_key           = "cloud-public-key-here"
    endpoint             = "cloud-server-ip:51820"
    allowed_ips          = ["10.100.0.10/32", "10.0.0.0/16"]
    comment              = "Cloud infrastructure"
    persistent_keepalive = 25
  }
}

# Static routes for remote networks
wireguard_routes = {
  "house-2-network" = {
    destination = "192.168.90.0/24"
    gateway     = "10.100.0.2"
    comment     = "Route to second house network"
  }
  "cloud-network" = {
    destination = "10.0.0.0/16"
    gateway     = "10.100.0.10"
    comment     = "Route to cloud infrastructure"
  }
}
```

### Network Configuration Examples

#### Site 1 (Current Location) - 192.168.89.0/24
```hcl
wireguard_local_ip = "10.100.0.1"
wireguard_peers = {
  "site-2" = {
    public_key  = "site2_public_key"
    endpoint    = "site2.example.com:51820"
    allowed_ips = ["10.100.0.2/32", "192.168.90.0/24"]
    comment     = "Site 2 - Remote House"
  }
}
```

#### Site 2 (Remote House) - 192.168.90.0/24
```hcl
wireguard_local_ip = "10.100.0.2"
wireguard_peers = {
  "site-1" = {
    public_key  = "site1_public_key"
    endpoint    = "site1.example.com:51820"
    allowed_ips = ["10.100.0.1/32", "192.168.89.0/24"]
    comment     = "Site 1 - Main House"
  }
}
```

### Firewall Rules
The configuration automatically creates the following firewall rules:

1. **WAN Input**: Allow WireGuard traffic on configured port
2. **VPN Input**: Allow traffic from WireGuard peers
3. **LAN ↔ VPN**: Bidirectional forwarding between LAN and VPN
4. **VPN ↔ VPN**: Mesh forwarding between VPN peers
5. **DNS**: Optional DNS forwarding for remote sites
6. **NAT**: Optional masquerading for internet access

### Monitoring and Troubleshooting

#### Check WireGuard Status
```bash
# View WireGuard interfaces
/interface wireguard print

# Check WireGuard peers
/interface wireguard peer print

# View WireGuard statistics
/interface wireguard peer print stats
```

#### Monitor VPN Traffic
```bash
# View firewall logs for WireGuard
/log print where message~"WireGuard"

# Check routing table
/ip route print where comment~"WireGuard"

# Test connectivity
/ping 10.100.0.2 count=5
```

#### Common Issues
- **Connection Failures**: Check firewall rules and endpoint accessibility
- **Routing Issues**: Verify static routes and allowed IPs configuration
- **Key Problems**: Ensure public/private key pairs are correctly configured
- **NAT Traversal**: Use persistent keepalive for connections behind NAT

### Security Considerations
- **Key Management**: Store private keys securely and rotate regularly
- **Network Segmentation**: Use appropriate allowed IPs to limit access
- **Firewall Rules**: Maintain restrictive rules for VPN traffic
- **Monitoring**: Regularly monitor VPN connections and traffic
- **Updates**: Keep WireGuard and RouterOS updated for security patches

## 📝 Notes

- This configuration assumes a single-subnet homelab setup
- Wireless interfaces (wlan1, wlan2) are bridged to LAN
- All containers/VMs should use the .200+ IP range
- DNS records point to the Docker host (192.168.89.253) for services
- Firewall rules are restrictive by default (deny-all approach)
