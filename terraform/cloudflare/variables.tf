variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (shown in the right-hand sidebar of the Cloudflare dashboard)"
  type        = string
}

variable "zone_name" {
  description = "Cloudflare DNS zone name to manage records in"
  type        = string
  default     = "dominiksiejak.pl"
}

variable "tunnel_name" {
  description = "Human-readable name for the Cloudflare Tunnel"
  type        = string
  default     = "homelab"
}

variable "tunnel_apps" {
  description = <<-EOT
    Map of public hostnames → internal origin services.
    Example:
    {
      "homeassistant-atom.dominiksiejak.pl" = "http://192.168.8.10:8123",
      "dns.dominiksiejak.pl"               = "http://192.168.89.10:80"
    }
    Leave a value empty ("") to skip creating that hostname.
  EOT
  type        = map(string)
  default = {
    "homeassistant-atom.dominiksiejak.pl" = ""
    "dns.dominiksiejak.pl"                = ""
    "firebird.dominiksiejak.pl"           = "tcp://v-maintenance-firebird:3050"
  }
}
