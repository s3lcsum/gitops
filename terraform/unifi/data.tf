# Controller built-ins (not TF-managed).

data "unifi_ap_group" "all" {
  name = "All APs"
}

data "unifi_network" "lan" {
  name = "Default"
}
