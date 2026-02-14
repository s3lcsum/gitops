variable "routeros_host" {
  description = "RouterOS host"
  type        = string
}

variable "routeros_username" {
  description = "RouterOS username"
  type        = string
}

variable "routeros_password" {
  description = "RouterOS password"
  type        = string
}

variable "wireguard_endpoint" {
  description = "WireGuard endpoint"
  type        = string
}

variable "wireguard_listen_port" {
  description = "WireGuard listen port"
  type        = string
}

variable "wireguard_peers" {
  description = "WireGuard peers names (key) and correspondIP addresses (value)"
  type        = map(string)
  default     = {}
}
