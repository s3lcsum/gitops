locals {
  groups = [
    "admins-authentik",
    "users-authentik",
  ]

  roles = {
    admins_authentik = {
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
    users_authentik = {
      role_id = "users-authentik"
      privileges = [
        "Datastore.Audit",
        "Sys.Audit",
        "VM.Audit",
      ]
    }
  }
}
