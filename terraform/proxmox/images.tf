resource "proxmox_virtual_environment_download_file" "latest_debian_12_standard_lxc_img" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = data.proxmox_virtual_environment_nodes.all_nodes.names[0]
  url          = "http://download.proxmox.com/images/system/debian-12-standard_12.7-1_amd64.tar.zst"
}

resource "proxmox_virtual_environment_download_file" "ubuntu_22_04_cloud_img" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = data.proxmox_virtual_environment_nodes.all_nodes.names[0]
  url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  file_name    = "ubuntu-22.04-server-cloudimg-amd64.img"
}
