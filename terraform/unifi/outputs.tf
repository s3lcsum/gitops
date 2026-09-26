output "wlan_ids" {
  description = "Managed WLAN IDs"
  value = {
    hass  = unifi_wlan.hass.id
    raval = unifi_wlan.raval.id
  }
}

output "wlan_names" {
  description = "Managed SSID names"
  value = {
    hass  = unifi_wlan.hass.name
    raval = unifi_wlan.raval.name
  }
}

output "u7_lite" {
  description = "U7 Lite device"
  value = {
    id  = unifi_device.u7_lite.id
    mac = unifi_device.u7_lite.mac
  }
}

output "device_ssh_username" {
  description = "Device SSH username (password in defaults.auto.tfvars / 1Password)"
  value       = var.device_ssh_username
}

output "device_ssh_password" {
  description = "Device SSH password (inventory only; provider cannot set it)"
  value       = var.device_ssh_password
  sensitive   = true
}
