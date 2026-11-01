locals {
  node_name = "lake-1"

  # Host is a single-node PVE 9.2.20 (kernel 7.0.14-17-pve) on an Intel N100.
  # vmbr0 192.168.89.254/24 gw 192.168.89.1, bridge-ports enp1s0 enp3s0.
  # Storage: dir local (/var/lib/vz), lvmthin local-lvm (vg pve, thinpool data).
  # Dual-run: CT 101 (.252) + QEMU 102 (.253). Do not manage the bridge or
  # datastores here — a bad apply drops the host.

  # Debian 13 LXC template already on the node. Used only as the import placeholder.
  # ignore_changes on template_file_id so plan does not reinstall a running rootfs.
  debian_template = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"

  # Debian 13 genericcloud image for QEMU (cloud-init). Downloaded to local.
  debian_cloud_image_url  = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
  debian_cloud_image_file = "debian-13-genericcloud-amd64.qcow2"
}
