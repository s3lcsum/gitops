# Non-secret defaults. Secrets: local.secret (ephemeral from OpenBao).
locals {
  cfg = {
    device_ssh_username = "s3lcsum"
    unifi_api_url       = "https://unifi.dominiksiejak.pl"
    unifi_site          = "default"
  }
}
