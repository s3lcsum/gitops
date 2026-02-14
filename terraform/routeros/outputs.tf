output "wireguard_configs" {
  value     = data.wireguard_config_document.peers
  sensitive = true
}
