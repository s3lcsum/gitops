output "node_name" {
  value = local.node_name
}

output "containers" {
  value = {
    docker = {
      vm_id = proxmox_virtual_environment_container.docker.vm_id
      ipv4  = "192.168.89.253/24"
    }
    k8s = {
      vm_id = proxmox_virtual_environment_container.k8s.vm_id
      ipv4  = "192.168.89.252/24"
    }
  }
}
