resource "vault_audit" "main" {
  count = var.vault_audit_enabled ? 1 : 0

  type        = "file"
  path        = "file"
  description = "Audit logs for Vault API requests"

  options = {
    file_path = var.vault_audit_file_path
  }
}
