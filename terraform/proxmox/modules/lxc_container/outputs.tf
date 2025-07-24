output "container_id" {
  value = proxmox_virtual_environment_container.this.id
}

output "hostname" {
  value = proxmox_virtual_environment_container.this.initialization[0].hostname
}
