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

  # Talos cluster (lake) — expected DHCP reservations for cert SANs / RouterOS; bbtechsys module discovers
  # live IPs via Proxmox + qemu-guest-agent (requires talos_schematic_id with that extension).
  talos_cluster_name   = "lake"
  talos_version        = "v1.12.6"
  talos_version_number = trimprefix(local.talos_version, "v")
  talos_nodes = {
    "cp-1" = { ipv4 = "192.168.89.210", mac = "BC:24:11:6E:89:21" }
    "cp-2" = { ipv4 = "192.168.89.211", mac = "BC:24:11:6E:89:22" }
    "cp-3" = { ipv4 = "192.168.89.212", mac = "BC:24:11:6E:89:23" }
  }
  talos_cp_ips = [for k in sort(keys(local.talos_nodes)) : local.talos_nodes[k].ipv4]
  # Sorted keys match talos_cp_ips order (cp-1, cp-2, cp-3).
  talos_cp_fqdns = var.talos_node_domain != "" ? [
    for k in sort(keys(local.talos_nodes)) : "talos-${k}.${var.talos_node_domain}"
  ] : []
  # API server certs: include both IPs and FQDNs when using DNS so kubectl works either way.
  talos_cp_cert_sans = length(local.talos_cp_fqdns) > 0 ? concat(local.talos_cp_ips, local.talos_cp_fqdns) : local.talos_cp_ips
  proxmox_node_name  = var.talos_proxmox_node != "" ? var.talos_proxmox_node : data.proxmox_virtual_environment_nodes.hosts.names[0]
}
