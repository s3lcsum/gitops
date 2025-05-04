resource "routeros_system_ntp_client" "test" {
  enabled = true
  mode    = "unicast"

  servers = ["tempus1.gum.gov.pl", "tempus2.gum.gov.pl"]
}
