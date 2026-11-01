resource "b2_bucket" "backup_buckets" {
  for_each = local.bucket_map

  bucket_name = each.key
  bucket_type = "allPrivate"

  bucket_info = merge(each.value, {
    domain     = "dominiksiejak"
    managed_by = "terraform"
  })

  # Opt-in only. B2 prefixes are literal (no globs) and an empty prefix would
  # hide + purge every backup, including the last full one. Set both days_*
  # keys on a bucket in locals.tf to enable expiry deliberately.
  dynamic "lifecycle_rules" {
    for_each = can(each.value.days_from_uploading_to_hiding) ? [each.value] : []
    content {
      file_name_prefix              = try(lifecycle_rules.value.file_name_prefix, "")
      days_from_hiding_to_deleting  = lifecycle_rules.value.days_from_hiding_to_deleting
      days_from_uploading_to_hiding = lifecycle_rules.value.days_from_uploading_to_hiding
    }
  }
}

resource "b2_application_key" "backup_keys" {
  for_each = local.bucket_map

  key_name  = each.key
  bucket_id = b2_bucket.backup_buckets[each.key].bucket_id
  capabilities = toset([
    "deleteFiles",
    "listBuckets",
    "listFiles",
    "readBucketEncryption",
    "readBucketLifecycleRules",
    "readBucketLogging",
    "readBucketNotifications",
    "readBucketReplications",
    "readBuckets",
    "readFiles",
    "shareFiles",
    "writeBucketEncryption",
    "writeBucketLifecycleRules",
    "writeBucketLogging",
    "writeBucketNotifications",
    "writeBucketReplications",
    "writeBuckets",
    "writeFiles",
  ])
}
