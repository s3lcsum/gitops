locals {
  # Network
  network_cidr    = "192.168.89.0/24"
  network_gateway = "192.168.89.1"

  # IPs
  control_ip = "192.168.89.250"

  # VM Config
  control_plane = {
    name      = "kube-control-01"
    vm_id     = 250
    cpu_cores = 2
    memory_mb = 4096
    disk_gb   = 32
  }

  workers = {
    "kube-worker-01" = {
      vm_id     = 251
      ip        = "192.168.89.251"
      cpu_cores = 1
      memory_mb = 4096
      disk_gb   = 32
    }
    "kube-worker-02" = {
      vm_id     = 252
      ip        = "192.168.89.252"
      cpu_cores = 1
      memory_mb = 4096
      disk_gb   = 32
    }
    "kube-worker-03" = {
      vm_id     = 253
      ip        = "192.168.89.253"
      cpu_cores = 1
      memory_mb = 4096
      disk_gb   = 32
    }
  }
}
