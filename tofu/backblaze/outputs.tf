output "config" {
  description = "Backup bucket + application key config (keyed by bucket name)"
  sensitive   = true

  value = {
    for key, bucket in local.bucket_map : key => {
      bucket = {
        bucket_name        = b2_bucket.backup_buckets[key].bucket_name
        bucket_id          = b2_bucket.backup_buckets[key].bucket_id
        key_name           = b2_application_key.backup_keys[key].key_name
        application_key_id = b2_application_key.backup_keys[key].application_key_id
        application_key    = b2_application_key.backup_keys[key].application_key
      }
    }
  }
}
