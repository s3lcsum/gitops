resource "grafana_service_account" "tf_scratch" {
  name        = "tf-scratch"
  role        = "Admin"
  is_disabled = false
}

resource "grafana_service_account_token" "tf_scratch" {
  name               = "tf-scratch-key"
  service_account_id = grafana_service_account.tf_scratch.id

  lifecycle {
    ignore_changes = [expiration]
  }
}