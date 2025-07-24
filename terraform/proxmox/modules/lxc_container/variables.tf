variable "node_name" {
  description = "The name of the Proxmox node where the LXC container will be created."
  type        = string
}

variable "hostname" {
  description = "The hostname to assign to the LXC container."
  type        = string
}

variable "disk" {
  description = "Disk configuration for the LXC container, including datastore and size."
  type = object({
    datastore_id = string
    size         = number
  })
}

variable "memory" {
  description = "Memory configuration for the LXC container, including dedicated and swap memory."
  type = object({
    dedicated = number
    swap      = number
  })
}

variable "network_interface" {
  description = "Network interface configuration, including bridge and interface name."
  type = object({
    bridge = string
    name   = string
  })
}

variable "os_type" {
  description = "The operating system type for the LXC container."
  type        = string
}

variable "template_file_id" {
  description = "The file ID of the template to use for the LXC container."
  type        = string
}

variable "ip_config" {
  description = "IP configuration for the LXC container, including IPv4 and IPv6 addresses and gateways."
  type = object({
    ipv4 = object({
      address = string
      gateway = string
    })
    ipv6 = object({
      address = string
      gateway = string
    })
  })
}

variable "dns" {
  description = "DNS configuration, including domain and list of DNS servers."
  type        = object({ domain = string, servers = list(string) })
  default     = null
}

variable "mount_points" {
  description = "List of mount points to be attached to the LXC container, each with a volume and path."
  type        = list(object({ volume = string, path = string }))
  default     = []
}
