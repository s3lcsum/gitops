# Credentials: use Terraform Cloud workspace variables and/or a local *.tfvars file
# (see repo .gitignore — *.tfvars are not committed).

variable "virtual_environment_endpoint" {
  type    = string
  default = "https://lake:8006"
}

variable "virtual_environment_api_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "oidc_issuer_url" {
  type    = string
  default = "https://auth.lake.dominiksiejak.pl/application/o/proxmox/"
}

variable "oidc_client_id" {
  type    = string
  default = "proxmox"
}

variable "oidc_client_secret" {
  type      = string
  sensitive = true
  default   = ""
}

variable "talos_proxmox_node" {
  type        = string
  description = "Proxmox node name to place Talos VMs on. Empty = first node from the API."
  default     = ""
}

variable "talos_datastore_id" {
  type        = string
  description = "Datastore for Talos VM disks (e.g. local-lvm). Passed to bbtechsys/talos/proxmox as proxmox_image_datastore."
  default     = "local-lvm"
}

variable "talos_import_datastore_id" {
  type        = string
  description = "File-based storage for Talos qcow2 download (not lvmthin). Passed as proxmox_iso_datastore."
  default     = "local"
}

variable "talos_bridge" {
  type        = string
  description = "Linux bridge for Talos VM NICs (e.g. vmbr0)."
  default     = "vmbr0"
}

variable "talos_control_vm_cores" {
  type        = number
  description = "vCPUs per control-plane VM (bbtechsys module)."
  default     = 2
}

variable "talos_control_vm_memory" {
  type        = number
  description = "RAM in MB per control-plane VM (bbtechsys module)."
  default     = 4096
}

variable "talos_control_vm_disk_size" {
  type        = number
  description = "Disk size in GB per control-plane VM (bbtechsys module)."
  default     = 32
}

variable "talos_proxmox_vm_cpu_type" {
  type        = string
  description = "Proxmox CPU type for Talos VMs (bbtechsys proxmox_vm_type)."
  default     = "host"
}

variable "talos_schematic_id" {
  type        = string
  description = "Talos Image Factory schematic. Must include qemu-guest-agent for bbtechsys/talos/proxmox (Proxmox IP discovery). Generate at https://factory.talos.dev/"
  default     = "ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515"
}

variable "talos_nameservers" {
  type        = list(string)
  description = "DNS resolvers written into Talos machine config."
  default     = ["1.1.1.1", "9.9.9.9"]
}

variable "talos_physical_interface" {
  type        = string
  description = "Linux interface for the virtio NIC (DHCP). Often ens18 or enp0s18."
  default     = "ens18"
}

variable "talos_node_domain" {
  type        = string
  description = "Parent DNS zone; FQDNs talos-<key>.<domain> are added to apiServer certSANs only. Leave empty for IP-only SANs."
  default     = ""
}

variable "bootstrap_calico" {
  type        = bool
  description = "After cluster kubeconfig exists, run helm to install Calico from kubernetes/platform/calico (required when Talos uses cni.name: none). Requires helm CLI. Set false to install Calico manually."
  default     = true
}
