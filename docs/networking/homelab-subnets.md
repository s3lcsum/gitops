# Homelab subnets and addressing

This page is the **human-readable** summary of how IP space is used at the **Lake** site. The **source of truth for Terraform** is versioned in-repo; **NetBox** should mirror the same prefixes after you apply `terraform/netbox`.

## IPv4 (LAN)

| CIDR | Role | Notes |
|------|------|--------|
| `192.168.89.0/24` | Primary LAN | DHCP, Wi‑Fi clients, servers, printers, NAS, and other trusted devices on the same L2 (or routed segments you treat as “internal”). |

**Default gateway:** `192.168.89.1` (typically RouterOS).

**Example static host:** Talos control plane VM `192.168.89.250/24` (see `terraform/proxmox/locals.tf`).

## IPv6 (RFC 4193 ULA)

Addresses are **Unique Local** (`fd00::/8`), for lab-only use. They are **not** derived from the IPv4 octets; short prefixes are chosen for readability.

| Prefix | Role | Notes |
|--------|------|--------|
| `fd12:34::/48` | Site ULA | Reserved for future **LAN** dual-stack or extra `/64` VLANs. Document child `/64`s here or in NetBox when you use them. |
| `fd12:35::/56` | Kubernetes **pods** | Used by Talos (`talos_pod_subnet`). Not for LAN hosts. |
| `fd12:36::/112` | Kubernetes **services** | ClusterIP-style IPv6 services (`talos_service_subnet`). Disjoint from pods. |

**Today:** the Talos node uses **IPv4 on `eth0`** for bootstrap and API reachability from your LAN; **pod/service traffic** uses the IPv6 CIDRs above inside the cluster.

## Where this is defined in Git

| What | Where |
|------|--------|
| Talos node IP, gateway, pod/service CIDRs | `terraform/proxmox/locals.tf` |
| NetBox prefixes (IPAM) | `terraform/netbox/data/networks.yaml` |
| Site name | `terraform/netbox/data/infrastructure.yaml` (`lake`) |

After changing prefixes, update **both** the Proxmox locals and `networks.yaml`, then run NetBox Terraform so IPAM stays aligned.

## NetBox

NetBox holds the **same prefixes** as `networks.yaml` once applied. Use it for **IPAM**, assignments, and **VLANs** when you split IoT/guest networks.

## Related

- Cursor rule with LAN context (addressing policy): `.cursor/rules/compose-networking.mdc`
- RouterOS Terraform: `terraform/routeros/`
