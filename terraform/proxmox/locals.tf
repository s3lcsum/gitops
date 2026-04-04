locals {
  # Provider
  virtual_environment_insecure  = true
  virtual_environment_ssh_agent = true
  virtual_environment_username  = "root"

  # OIDC
  enable_oidc         = true
  oidc_realm          = "authentik"
  oidc_autocreate     = true
  oidc_username_claim = "username"

  # Extra users (Proxmox requires user@realm format)
  extra_users = {
    "terraform@pve" = { comment = "Terraform automation", enabled = true }
    "metrics@pve"   = { comment = "VictoriaMetrics read-only", enabled = true }
  }
  extra_user_tokens = {
    "terraform@pve" = { token_name = "terraform", comment = "Provider authentication" }
    "metrics@pve"   = { token_name = "victoriametrics", comment = "VictoriaMetrics scrape" }
  }
  metrics_role_privileges = ["Datastore.Audit", "Sys.Audit", "VM.Audit"]

  # Authentik groups/roles
  authentik_groups = ["admins-authentik", "users-authentik"]
  authentik_roles = {
    admins_authentik = {
      role_id = "admins-authentik"
      privileges = [
        "Datastore.Allocate", "Datastore.AllocateSpace", "Datastore.AllocateTemplate",
        "Datastore.Audit", "Pool.Allocate", "Sys.Audit", "Sys.Modify", "VM.Allocate",
        "VM.Audit", "VM.Clone", "VM.Config.CDROM", "VM.Config.CPU", "VM.Config.Disk",
        "VM.Config.HWType", "VM.Config.Memory", "VM.Config.Network", "VM.Config.Options",
        "VM.Migrate", "VM.PowerMgmt",
      ]
    }
    users_authentik = {
      role_id    = "users-authentik"
      privileges = ["Datastore.Audit", "Sys.Audit", "VM.Audit"]
    }
  }

  # Talos — node definitions
  # `ip` must be reachable before `talos_machine_configuration_apply` runs: reserve this IP in DHCP for the VM’s MAC,
  # or first-boot Talos will use another address and Terraform (which targets `ip`) will hang until `.250` answers.
  talos_nodes = {
    "talos-cp-1" = {
      host_node     = "lake-1"
      machine_type  = "controlplane"
      ip            = "192.168.89.250"
      vm_id         = 500
      cpu           = 4
      ram_dedicated = 16384
    }
  }

  # Derived node helpers (bootstrap uses lexicographically first control-plane key)
  talos_controlplane_nodes = { for k, v in local.talos_nodes : k => v if v.machine_type == "controlplane" }
  talos_bootstrap_node_key = sort(keys(local.talos_controlplane_nodes))[0]
  talos_first_cp_ip        = local.talos_controlplane_nodes[local.talos_bootstrap_node_key].ip

  # Talos cluster config
  proxmox_storage          = "local"
  proxmox_datastore_id     = "local-lvm"
  vm_gateway               = "192.168.89.1"
  talos_cluster_name       = "homelab"
  talos_kubernetes_version = "1.32.0"
  talos_image_version      = "v1.11.4"
  talos_network_bridge     = "vmbr0"

  # IPv6-only pod/service CIDRs (RFC 4193 ULA, structured from 89 → 192.168.89.x)
  talos_pod_subnet     = "fd89:dead:beef::/48"
  talos_service_subnet = "fd89:cafe:babe::/112"

  # Image factory
  talos_factory_url = "https://factory.talos.dev"
  talos_platform    = "nocloud"
  talos_arch        = "amd64"

  talos_schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = [
          "siderolabs/i915-ucode",
          "siderolabs/intel-ucode",
          "siderolabs/qemu-guest-agent",
          "siderolabs/iscsi-tools",
        ]
      }
    }
  })

  schematic_id = jsondecode(data.http.schematic_id.response_body)["id"]
  image_id     = "${local.schematic_id}_${local.talos_image_version}"

  # ArgoCD bootstrap
  argocd_manifest_url = "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

  # Cluster endpoint
  cluster_endpoint = "https://${local.talos_first_cp_ip}:6443"
}
