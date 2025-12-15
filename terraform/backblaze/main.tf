resource "b2_bucket" "backup_buckets" {
  for_each = local.bucket_map

  bucket_name = each.key
  bucket_type = "allPrivate"

  bucket_info = merge(each.value, {
    domain     = "dominiksiejak"
    managed_by = "terraform"
  })

  lifecycle_rules {
    file_name_prefix              = try(each.value.file_name_prefix, "*")
    days_from_hiding_to_deleting  = try(each.value.days_from_hiding_to_deleting, 30)
    days_from_uploading_to_hiding = try(each.value.days_from_uploading_to_hiding, 30)
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
