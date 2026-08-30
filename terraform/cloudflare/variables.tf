variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (shown in the right-hand sidebar of the Cloudflare dashboard)"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token used by the provider"
  type        = string
  sensitive   = true
}

variable "zone_name" {
  description = "Cloudflare DNS zone name to manage records in"
  type        = string
  default     = "dominiksiejak.pl"
}

variable "tunnel_name" {
  description = "Human-readable name for the Cloudflare Tunnel"
  type        = string
  # Keep this equal to the live tunnel name. Renaming forces a new tunnel UUID.
  default = "homelab"
}

variable "tunnel_team_name" {
  description = "Cloudflare Zero Trust organization (team) name, required for origin_request.access"
  type        = string
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
    # Firebird TCP on the tunnel is opt-in only — do not expose DB protocol by default.
    "firebird.dominiksiejak.pl" = ""
    "n8n.dominiksiejak.pl"      = "https://traefik"
    "auth.dominiksiejak.pl"     = "https://traefik"
    "hass.dominiksiejak.pl"     = "https://traefik"
  }
}
