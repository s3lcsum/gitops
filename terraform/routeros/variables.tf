# Variables for RouterOS configuration

variable "network_cidr" {
  description = "Main network CIDR"
  type        = string
  default     = "192.168.89.0/24"
}

variable "gateway_ip" {
  description = "Gateway IP address"
  type        = string
  default     = "192.168.89.1"
}

variable "dhcp_pool_start" {
  description = "DHCP pool start IP"
  type        = string
  default     = "192.168.89.100"
}

variable "dhcp_pool_end" {
  description = "DHCP pool end IP"
  type        = string
  default     = "192.168.89.199"
}

variable "dns_servers" {
  description = "DNS servers list"
  type        = list(string)
  default     = ["192.168.89.251", "1.1.1.1", "1.0.0.1"]
}

variable "domain_name" {
  description = "Local domain name"
  type        = string
  default     = "lake.dominiksiejak.pl"
}

variable "ntp_servers" {
  description = "NTP servers list"
  type        = list(string)
  default     = ["tempus1.gum.gov.pl", "tempus2.gum.gov.pl", "pool.ntp.org"]
}

variable "router_identity" {
  description = "Router system identity"
  type        = string
  default     = "MikroTik-hAP-ac3"
}

# Cloudflare DDNS Configuration
variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS updates"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_dns_records" {
  description = "List of DNS records to update with current public IP"
  type = list(object({
    name = string
    type = string
  }))
  default = [
    {
      name = "home.dominiksiejak.pl"
      type = "A"
    }
  ]
}

variable "enable_ddns" {
  description = "Enable Cloudflare DDNS functionality"
  type        = bool
  default     = false
}

# WireGuard VPN Configuration
variable "enable_wireguard" {
  description = "Enable WireGuard VPN mesh network"
  type        = bool
  default     = false
}

variable "wireguard_listen_port" {
  description = "WireGuard listen port"
  type        = number
  default     = 51820
}

variable "wireguard_private_key" {
  description = "WireGuard private key for this router"
  type        = string
  sensitive   = true
  default     = ""
}

variable "wireguard_local_ip" {
  description = "Local IP address for WireGuard interface"
  type        = string
  default     = "10.100.0.1"
}

variable "wireguard_network_prefix" {
  description = "Network prefix for WireGuard network"
  type        = number
  default     = 24
}

variable "wireguard_network_cidr" {
  description = "WireGuard network CIDR"
  type        = string
  default     = "10.100.0.0/24"
}

variable "wireguard_enable_nat" {
  description = "Enable NAT for WireGuard traffic to internet"
  type        = bool
  default     = true
}

variable "wireguard_peers" {
  description = "WireGuard peer configurations"
  type = map(object({
    public_key           = string
    endpoint             = string
    allowed_ips          = list(string)
    comment              = string
    persistent_keepalive = optional(number)
  }))
  default = {
    # Example peer configuration for second house
    "house-2" = {
      public_key           = "" # To be filled with actual public key
      endpoint             = "" # To be filled with actual endpoint
      allowed_ips          = ["10.100.0.2/32", "192.168.90.0/24"]
      comment              = "Second house location"
      persistent_keepalive = 25
    }
    # Example peer configuration for cloud infrastructure
    "cloud-infra" = {
      public_key           = "" # To be filled with actual public key
      endpoint             = "" # To be filled with actual endpoint
      allowed_ips          = ["10.100.0.10/32", "10.0.0.0/16"]
      comment              = "Cloud infrastructure"
      persistent_keepalive = 25
    }
  }
}

variable "wireguard_routes" {
  description = "Static routes for WireGuard networks"
  type = map(object({
    destination = string
    gateway     = string
    comment     = string
    distance    = optional(number)
  }))
  default = {
    # Route to second house network
    "house-2-network" = {
      destination = "192.168.90.0/24"
      gateway     = "10.100.0.2"
      comment     = "Route to second house network"
      distance    = 1
    }
    # Route to cloud infrastructure
    "cloud-network" = {
      destination = "10.0.0.0/16"
      gateway     = "10.100.0.10"
      comment     = "Route to cloud infrastructure"
      distance    = 1
    }
  }
}

# WireGuard Peer Public Keys
variable "wireguard_peer_public_keys" {
  description = "Public keys for each WireGuard peer (indexed by peer name: peer0, peer1, etc.)"
  type        = map(string)
  sensitive   = true
  default = {
    peer0 = "" # Dominik's iPad
    peer1 = "" # Dominik's iPhone
    peer2 = "" # Dominik's Macbook
    peer3 = "" # atom-1
    peer4 = "" # jsejak iPhone
    peer5 = "" # jsejak Macbook
  }
}

# RADIUS Configuration for Keycloak/FreeRADIUS Authentication
variable "enable_radius" {
  description = "Enable RADIUS authentication for router login"
  type        = bool
  default     = false
}

variable "radius_server" {
  description = "RADIUS server IP address (FreeRADIUS)"
  type        = string
  default     = "192.168.89.252"
}

variable "radius_secret" {
  description = "RADIUS shared secret (must match FreeRADIUS configuration)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "radius_timeout" {
  description = "RADIUS timeout in milliseconds"
  type        = number
  default     = 3000
}

# Note: User configuration is not supported by the RouterOS provider
# Users must be configured manually via RouterOS interface
