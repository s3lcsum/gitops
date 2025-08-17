# All Bucket Information
output "bucket_names" {
  description = "Names of all backup buckets"
  value       = { for k, v in b2_bucket.backup_buckets : k => v.bucket_name }
}

output "bucket_ids" {
  description = "IDs of all backup buckets"
  value       = { for k, v in b2_bucket.backup_buckets : k => v.bucket_id }
}

# All Application Key Information (sensitive)
output "backup_key_ids" {
  description = "Application Key IDs for all backup buckets"
  value       = { for k, v in b2_application_key.backup_keys : k => v.application_key_id }
  sensitive   = true
}

output "backup_keys" {
  description = "Application Keys for all backup buckets"
  value       = { for k, v in b2_application_key.backup_keys : k => v.application_key }
  sensitive   = true
}

# Individual outputs for backward compatibility
output "atom_1_hass_bucket_name" {
  description = "Name of the Atom-1 Home Assistant backups bucket"
  value       = b2_bucket.backup_buckets["atom-1-hass-backups"].bucket_name
}

output "atom_1_hass_bucket_id" {
  description = "ID of the Atom-1 Home Assistant backups bucket"
  value       = b2_bucket.backup_buckets["atom-1-hass-backups"].bucket_id
}

output "atom_1_proxmox_bucket_name" {
  description = "Name of the Atom-1 Proxmox snapshots bucket"
  value       = b2_bucket.backup_buckets["atom-1-proxmox-snapshots"].bucket_name
}

output "atom_1_proxmox_bucket_id" {
  description = "ID of the Atom-1 Proxmox snapshots bucket"
  value       = b2_bucket.backup_buckets["atom-1-proxmox-snapshots"].bucket_id
}

output "wally_1_routeros_bucket_name" {
  description = "Name of the Wally-1 RouterOS backups bucket"
  value       = b2_bucket.backup_buckets["wally-1-routeros-backups"].bucket_name
}

output "wally_1_routeros_bucket_id" {
  description = "ID of the Wally-1 RouterOS backups bucket"
  value       = b2_bucket.backup_buckets["wally-1-routeros-backups"].bucket_id
}

output "wally_1_proxmox_bucket_name" {
  description = "Name of the Wally-1 Proxmox snapshots bucket"
  value       = b2_bucket.backup_buckets["wally-1-proxmox-snapshots"].bucket_name
}

output "wally_1_proxmox_bucket_id" {
  description = "ID of the Wally-1 Proxmox snapshots bucket"
  value       = b2_bucket.backup_buckets["wally-1-proxmox-snapshots"].bucket_id
}

# Individual application key outputs for backward compatibility
output "atom_1_hass_backup_key_id" {
  description = "Application Key ID for Atom-1 Home Assistant backups"
  value       = b2_application_key.backup_keys["atom-1-hass-backups"].application_key_id
  sensitive   = true
}

output "atom_1_hass_backup_key" {
  description = "Application Key for Atom-1 Home Assistant backups"
  value       = b2_application_key.backup_keys["atom-1-hass-backups"].application_key
  sensitive   = true
}

output "atom_1_proxmox_backup_key_id" {
  description = "Application Key ID for Atom-1 Proxmox backups"
  value       = b2_application_key.backup_keys["atom-1-proxmox-snapshots"].application_key_id
  sensitive   = true
}

output "atom_1_proxmox_backup_key" {
  description = "Application Key for Atom-1 Proxmox backups"
  value       = b2_application_key.backup_keys["atom-1-proxmox-snapshots"].application_key
  sensitive   = true
}

output "wally_1_routeros_backup_key_id" {
  description = "Application Key ID for Wally-1 RouterOS backups"
  value       = b2_application_key.backup_keys["wally-1-routeros-backups"].application_key_id
  sensitive   = true
}

output "wally_1_routeros_backup_key" {
  description = "Application Key for Wally-1 RouterOS backups"
  value       = b2_application_key.backup_keys["wally-1-routeros-backups"].application_key
  sensitive   = true
}

output "wally_1_proxmox_backup_key_id" {
  description = "Application Key ID for Wally-1 Proxmox backups"
  value       = b2_application_key.backup_keys["wally-1-proxmox-snapshots"].application_key_id
  sensitive   = true
}

output "wally_1_proxmox_backup_key" {
  description = "Application Key for Wally-1 Proxmox backups"
  value       = b2_application_key.backup_keys["wally-1-proxmox-snapshots"].application_key
  sensitive   = true
}
