# Non-secret defaults. Secrets: local.secret (ephemeral from OpenBao).
# Inventory lives under catalog/ (YAML). Tofu uses TF_API_TOKEN (fallback netbox_api_token).
locals {
  cfg = {}
}
