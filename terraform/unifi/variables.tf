variable "unifi_api_url" {
  description = "UniFi Network Application URL"
  type        = string
  default     = "https://unifi.dominiksiejak.pl"
}

variable "unifi_site" {
  description = "UniFi site name"
  type        = string
  default     = "default"
}

variable "unifi_username" {
  description = "Local UniFi admin (1Password: UniFi | localadmin)"
  type        = string
}

variable "unifi_password" {
  description = "Local UniFi admin password (1Password: UniFi | localadmin)"
  type        = string
  sensitive   = true
}

variable "wlan_passphrase_hass" {
  description = "Passphrase for SSID Hass (1Password: WiFi | Hass)"
  type        = string
  sensitive   = true
}

variable "wlan_passphrase_raval" {
  description = "Passphrase for SSID Raval (1Password: WiFi | Raval)"
  type        = string
  sensitive   = true
}

variable "device_ssh_username" {
  description = "Device SSH user (1Password: UniFi | device-ssh) — inventory only"
  type        = string
  default     = "s3lcsum"
}

variable "device_ssh_password" {
  description = "Device SSH password (1Password: UniFi | device-ssh) — inventory only"
  type        = string
  sensitive   = true
  default     = ""
}
