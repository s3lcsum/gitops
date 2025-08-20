variable "netbox_url" {
  description = "NetBox server URL"
  type        = string
  default     = "https://netbox.lake.dominiksiejak.pl"
}

variable "netbox_api_token" {
  description = "NetBox API token"
  type        = string
  sensitive   = true
}

variable "site_name" {
  description = "Site name for the homelab"
  type        = string
  default     = "Homelab"
}

variable "domain_name" {
  description = "Domain name for the homelab"
  type        = string
  default     = "lake.dominiksiejak.pl"
}
