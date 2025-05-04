resource "proxmox_virtual_environment_download_file" "latest_debian_12_standard_lxc_img" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = data.proxmox_virtual_environment_nodes.all_nodes.names[0]
  url          = "http://download.proxmox.com/images/system/debian-12-standard_12.7-1_amd64.tar.zst"
}
