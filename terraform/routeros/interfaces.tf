resource "routeros_interface_bridge" "bridge" {
  name           = "bridge"
  comment        = "defconf"
  vlan_filtering = false
}
