# -----------------------------------------------------------------------------
# OIDC (Authentik) realm
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_realm_openid" "authentik" {
  count = local.enable_oidc && var.oidc_client_secret != "" ? 1 : 0

  realm      = local.oidc_realm
  issuer_url = var.oidc_issuer_url
  client_id  = var.oidc_client_id
  client_key = var.oidc_client_secret

  autocreate     = local.oidc_autocreate
  username_claim = local.oidc_username_claim
  scopes         = "openid email profile"
  query_userinfo = true
  comment        = "Authentik OIDC managed by OpenTofu"
}

# -----------------------------------------------------------------------------
# Extra users (terraform + metrics)
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_user" "extra" {
  for_each = local.extra_users

  user_id = each.key
  comment = each.value.comment
  enabled = each.value.enabled

  lifecycle {
    ignore_changes = [acl]
  }
}

resource "proxmox_virtual_environment_user_token" "extra" {
  for_each = {
    for k, v in local.extra_user_tokens : k => v
    if contains(keys(local.extra_users), k)
  }

  user_id               = proxmox_virtual_environment_user.extra[each.key].user_id
  token_name            = each.value.token_name
  comment               = lookup(each.value, "comment", "Managed by OpenTofu")
  privileges_separation = false # Required for Terraform to manage Proxmox resources
}

# Metrics read-only role and ACL
resource "proxmox_virtual_environment_role" "metrics_readonly" {
  role_id    = "metrics-readonly"
  privileges = local.metrics_role_privileges
}

resource "proxmox_virtual_environment_acl" "metrics" {
  path    = "/"
  role_id = proxmox_virtual_environment_role.metrics_readonly.role_id
  user_id = proxmox_virtual_environment_user.extra["metrics@pve"].user_id
}

# -----------------------------------------------------------------------------
# Authentik groups and roles (OIDC mapping)
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_group" "authentik" {
  for_each = toset(local.authentik_groups)

  group_id = each.key
  comment  = "Managed by OpenTofu"

  lifecycle {
    ignore_changes = [acl]
  }
}

resource "proxmox_virtual_environment_role" "authentik" {
  for_each = local.authentik_roles

  role_id    = each.value.role_id
  privileges = each.value.privileges
}

# -----------------------------------------------------------------------------
# Talos Linux Kubernetes — multi-node via for_each
# -----------------------------------------------------------------------------

resource "talos_machine_secrets" "this" {
  talos_version = local.talos_image_version
}

resource "proxmox_virtual_environment_vm" "talos" {
  for_each = local.talos_nodes

  name      = each.key
  node_name = each.value.host_node
  vm_id     = each.value.vm_id

  machine = "q35"
  bios    = "ovmf"

  cpu {
    cores = each.value.cpu
  }

  memory {
    dedicated = each.value.ram_dedicated
  }

  # Attach factory raw as scsi0 via `file_id` (not CD-ROM). Omit `size` here — setting it can force a hot resize on the boot disk and fail on a running VM.
  disk {
    datastore_id = local.proxmox_datastore_id
    file_id      = proxmox_virtual_environment_download_file.talos_iso["${each.value.host_node}_${local.image_id}"].id
    file_format  = "raw"
    interface    = "scsi0"
    ssd          = true
    discard      = "on"
    backup       = true
  }

  efi_disk {
    datastore_id = local.proxmox_datastore_id
    file_format  = "raw"
    type         = "4m"
  }

  boot_order = ["scsi0"]

  network_device {
    bridge = local.talos_network_bridge
    model  = "virtio"
  }

  agent {
    enabled = true
  }
}

resource "talos_machine_configuration_apply" "this" {
  for_each = local.talos_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  node                        = each.value.ip
  endpoint                    = each.value.ip

  depends_on = [proxmox_virtual_environment_vm.talos]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.talos_first_cp_ip
  endpoint             = local.talos_first_cp_ip

  depends_on = [talos_machine_configuration_apply.this]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.talos_first_cp_ip
  endpoint             = local.talos_first_cp_ip

  depends_on = [talos_machine_bootstrap.this]
}
