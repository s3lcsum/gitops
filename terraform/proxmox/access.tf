resource "proxmox_virtual_environment_role" "terraform" {
  role_id = "Terraform"
  privileges = [
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.AllocateTemplate",
    "Datastore.Audit",
    "Group.Allocate",
    "Mapping.Audit",
    "Mapping.Modify",
    "Mapping.Use",
    "Permissions.Modify",
    "Pool.Allocate",
    "Pool.Audit",
    "Realm.Allocate",
    "Realm.AllocateUser",
    "SDN.Allocate",
    "SDN.Audit",
    "SDN.Use",
    "Sys.AccessNetwork",
    "Sys.Audit",
    "Sys.Console",
    "Sys.Incoming",
    "Sys.Modify",
    "Sys.PowerMgmt",
    "Sys.Syslog",
    "User.Modify",
    "VM.Allocate",
    "VM.Audit",
    "VM.Backup",
    "VM.Clone",
    "VM.Config.CDROM",
    "VM.Config.CPU",
    "VM.Config.Cloudinit",
    "VM.Config.Disk",
    "VM.Config.HWType",
    "VM.Config.Memory",
    "VM.Config.Network",
    "VM.Config.Options",
    "VM.Console",
    "VM.GuestAgent.Audit",
    "VM.GuestAgent.FileRead",
    "VM.GuestAgent.FileSystemMgmt",
    "VM.GuestAgent.FileWrite",
    "VM.GuestAgent.Unrestricted",
    "VM.Migrate",
    "VM.PowerMgmt",
    "VM.Replicate",
    "VM.Snapshot",
    "VM.Snapshot.Rollback",
  ]
}

resource "proxmox_virtual_environment_role" "admins_authentik" {
  role_id = "admins-authentik"
  privileges = [
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.AllocateTemplate",
    "Datastore.Audit",
    "Pool.Allocate",
    "Sys.Audit",
    "Sys.Modify",
    "VM.Allocate",
    "VM.Audit",
    "VM.Clone",
    "VM.Config.CDROM",
    "VM.Config.CPU",
    "VM.Config.Disk",
    "VM.Config.HWType",
    "VM.Config.Memory",
    "VM.Config.Network",
    "VM.Config.Options",
    "VM.Migrate",
    "VM.PowerMgmt",
  ]
}

resource "proxmox_virtual_environment_role" "metrics_readonly" {
  role_id = "metrics-readonly"
  privileges = [
    "Datastore.Audit",
    "Sys.Audit",
    "VM.Audit",
  ]
}

resource "proxmox_virtual_environment_role" "users_authentik" {
  role_id = "users-authentik"
  privileges = [
    "Datastore.Audit",
    "Sys.Audit",
    "VM.Audit",
  ]
}

resource "proxmox_virtual_environment_group" "admins_authentik" {
  comment  = "Managed by OpenTofu"
  group_id = "admins-authentik"
}

resource "proxmox_virtual_environment_group" "users_authentik" {
  comment  = "Managed by OpenTofu"
  group_id = "users-authentik"
}

# s3lcsum@authentik is created by the realm on login. Do not declare the user
# here — a missing password on @pve is required, but an OIDC user has none,
# and destroy would drop the only admin login.

resource "proxmox_acl" "terraform" {
  user_id   = "terraform@pve"
  role_id   = proxmox_virtual_environment_role.terraform.role_id
  path      = "/"
  propagate = true
}

resource "proxmox_acl" "metrics" {
  user_id   = "metrics@pve"
  role_id   = proxmox_virtual_environment_role.metrics_readonly.role_id
  path      = "/"
  propagate = true
}

resource "proxmox_acl" "admins_authentik" {
  group_id  = proxmox_virtual_environment_group.admins_authentik.group_id
  role_id   = proxmox_virtual_environment_role.admins_authentik.role_id
  path      = "/"
  propagate = true
}

resource "proxmox_realm_openid" "authentik" {
  realm          = "authentik"
  issuer_url     = var.proxmox_openid_issuer_url
  client_id      = var.proxmox_openid_client_id
  client_key     = var.proxmox_openid_client_secret
  username_claim = "username"
  autocreate     = true
  default        = true
  scopes         = "openid email profile"
  query_userinfo = true
  comment        = "Authentik OIDC managed by OpenTofu"
}
