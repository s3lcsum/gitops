# Create all backup buckets using for_each
resource "b2_bucket" "backup_buckets" {
  for_each = local.buckets

  bucket_name = each.key
  bucket_type = "allPrivate"
}

# Create write-only application keys for each bucket
resource "b2_application_key" "backup_keys" {
  for_each = local.buckets

  key_name  = "${each.key}-backup-key"
  bucket_id = b2_bucket.backup_buckets[each.key].bucket_id

  capabilities = [
    "listFiles",
    "writeFiles"
  ]
}
