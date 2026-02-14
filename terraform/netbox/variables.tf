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
