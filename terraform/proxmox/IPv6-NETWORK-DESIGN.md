# IPv6 Network Design for Homelab

## Overview
This document describes the IPv6 addressing scheme for the homelab infrastructure using Unique Local Addresses (ULA).

## Base Network: `fd89::/48`

### Network Segmentation

| Segment | Prefix | Purpose | Description |
|---------|--------|---------|-------------|
| Infrastructure | `fd89:0000::/56` | Network Infrastructure | Routers, switches, network equipment |
| Services | `fd89:0001::/56` | Core Services | DNS, databases, monitoring, shared services |
| Compute | `fd89:0002::/56` | Virtual Machines | VMs, compute nodes, K3s nodes |
| Containers | `fd89:0003::/56` | LXC Containers | Application containers, isolated workloads |
| Applications | `fd89:0004::/56` | Application Workloads | Kubernetes pods, application services |

### Current Address Assignments

#### Services Network (`fd89:1::/64`)
- **Gateway**: `fd89:1::1`
- **AdGuard DNS**: `fd89:1::53` (192.168.89.251)
- **PostgreSQL**: `fd89:1::252` (192.168.89.252)

#### Compute Network (`fd89:2::/64`)
- **Gateway**: `fd89:2::1`
- **K3s Node 01**: `fd89:2::100` (192.168.89.100)

#### Containers Network (`fd89:3::/64`)
- **Gateway**: `fd89:3::1`
- **Portainer**: `fd89:3::253` (192.168.89.253)

### Reserved Address Ranges

#### Infrastructure (`fd89:0::/64`)
- `fd89:0::1` - Primary gateway/router
- `fd89:0::2-10` - Network equipment
- `fd89:0::11-50` - Switches and access points

#### Services (`fd89:1::/64`)
- `fd89:1::1` - Gateway
- `fd89:1::53` - DNS (AdGuard)
- `fd89:1::80` - Web proxy/load balancer
- `fd89:1::443` - HTTPS proxy
- `fd89:1::100-199` - Monitoring services
- `fd89:1::200-299` - Database services

#### Compute (`fd89:2::/64`)
- `fd89:2::1` - Gateway
- `fd89:2::100-199` - K3s nodes
- `fd89:2::200-299` - General VMs
- `fd89:2::300-399` - Development VMs

#### Containers (`fd89:3::/64`)
- `fd89:3::1` - Gateway
- `fd89:3::100-199` - System containers
- `fd89:3::200-299` - Application containers
- `fd89:3::300-399` - Development containers

#### Applications (`fd89:4::/64`)
- `fd89:4::1` - Gateway
- `fd89:4::100-199` - Production applications
- `fd89:4::200-299` - Staging applications
- `fd89:4::300-399` - Development applications

## Benefits of This Design

1. **Hierarchical Structure**: Clear separation of different service types
2. **Scalability**: Each segment has 65,536 addresses available
3. **Security**: Network segmentation enables better firewall rules
4. **Management**: Easy to identify service type from address
5. **Future Growth**: Room for expansion in each category

## Implementation Notes

- All gateways use `::1` in their respective subnets
- DNS services are consistently at `::53` addresses
- Service-specific ports are reflected in addresses where logical
- IPv4 and IPv6 are dual-stacked for compatibility

## Cloudflare Tunnel Integration

This homelab uses Cloudflare Tunnel to securely expose services to the internet without opening firewall ports. The tunnel daemon can connect to IPv6 services directly.

### Tunnel Configuration Benefits
- **Zero Trust Access**: No inbound firewall rules needed
- **IPv6 Native**: Direct connection to IPv6 services
- **SSL Termination**: Automatic HTTPS with Cloudflare certificates
- **DDoS Protection**: Built-in protection from Cloudflare
- **Access Control**: Cloudflare Access for authentication

### Recommended Tunnel Endpoints
- **Portainer**: `fd89:3::253:9000` → `portainer.wally.dominiksiejak.pl`
- **AdGuard**: `fd89:1::53:80` → `adguard.wally.dominiksiejak.pl`
- **K3s Services**: `fd89:2::100:*` → `*.k3s.wally.dominiksiejak.pl`
- **PostgreSQL Admin**: Via web interface on separate container

### Security Considerations
- Services remain isolated on internal IPv6 network
- Only tunnel daemon needs internet access
- All external traffic goes through Cloudflare edge
- Internal services can use IPv6-only configuration

## Next Steps

1. Configure router/firewall with these IPv6 subnets
2. Update DHCP/SLAAC configuration
3. Deploy Cloudflare Tunnel daemon (cloudflared)
4. Configure tunnel routes for each service
5. Set up Cloudflare Access policies
6. Update monitoring to track IPv6 connectivity
