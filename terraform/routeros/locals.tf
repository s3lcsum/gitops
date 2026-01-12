# Local values for RouterOS and WireGuard configuration

locals {
  # WireGuard Peers Configuration
  # Each peer can have a static private key, IP address, and connection details
  wireguard_peers = {
    # Dominik's Devices
    peer0 = {
      name           = "Dominik's iPad"
      ip_address     = "192.168.200.23"
      wg_ip          = "10.100.0.10"
      # private_key   = "" # Set via environment variable or terraform.tfvars
      comment        = "Dominik's iPad on WireGuard mesh"
    }
    peer1 = {
      name           = "Dominik's iPhone"
      ip_address     = "192.168.200.22"
      wg_ip          = "10.100.0.11"
      # private_key   = "" # Set via environment variable or terraform.tfvars
      comment        = "Dominik's iPhone on WireGuard mesh"
    }
    peer2 = {
      name           = "Dominik's Macbook"
      ip_address     = "192.168.200.21"
      wg_ip          = "10.100.0.12"
      # private_key   = "" # Set via environment variable or terraform.tfvars
      comment        = "Dominik's Macbook on WireGuard mesh"
    }

    # Atom-1 Server
    peer3 = {
      name           = "atom-1"
      ip_address     = "192.168.200.1"
      wg_ip          = "10.100.0.100"
      # private_key   = "" # Set via environment variable or terraform.tfvars
      comment        = "atom-1 server on WireGuard mesh"
    }

    # jsejak Devices
    peer4 = {
      name           = "jsejak iPhone"
      ip_address     = "192.168.200.31"
      wg_ip          = "10.100.0.20"
      # private_key   = "" # Set via environment variable or terraform.tfvars
      comment        = "jsejak's iPhone on WireGuard mesh"
    }
    peer5 = {
      name           = "jsejak Macbook"
      ip_address     = "192.168.200.32"
      wg_ip          = "10.100.0.21"
      # private_key   = "" # Set via environment variable or terraform.tfvars
      comment        = "jsejak's Macbook on WireGuard mesh"
    }
  }

  # Generate Terraform-friendly peer structure for WireGuard resources
  # Each peer will be provisioned with public key from their configuration
  wg_peers_for_terraform = {
    for peer_name, peer_config in local.wireguard_peers :
    peer_name => {
      public_key           = var.wireguard_peer_public_keys[peer_name]
      allowed_ips          = ["${peer_config.wg_ip}/32"]
      endpoint             = ""
      comment              = peer_config.comment
      persistent_keepalive = 25
    }
  }

  # Common tags for all resources
  common_tags = {
    Project     = "routeros-wireguard"
    ManagedBy   = "terraform"
    Environment = "production"
  }
}



