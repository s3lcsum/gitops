locals {
  # Opt-in expiry, matching the dynamic block in main.tf. B2 prefixes are
  # literal (no globs), so file_name_prefix = "" means every object in the
  # bucket. Hidden versions still bill at $6/TB/mo, hence the hide + delete.
  # 90d live -> hidden -> 30d -> purged (120d total).
  lifecycle_expiry = {
    file_name_prefix              = ""
    days_from_uploading_to_hiding = 90
    days_from_hiding_to_deleting  = 30
  }

  buckets = [
    {
      app      = "hass"
      instance = "atom-1"
      purpose  = "backups"
    },
    {
      app      = "hass"
      instance = "lake-1"
      purpose  = "backups"
    },
  ]

  bucket_map = {
    for bucket in local.buckets : "dominiksiejak-${bucket.app}-${bucket.instance}-${bucket.purpose}" => merge(bucket, local.lifecycle_expiry)
  }

  # Keys consumed by the lifecycle_rules dynamic block; filtered out of bucket_info.
  lifecycle_keys = {
    file_name_prefix              = true
    days_from_uploading_to_hiding = true
    days_from_hiding_to_deleting  = true
  }
}
