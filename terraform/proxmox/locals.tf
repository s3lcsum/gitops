locals {
  node_name = "lake-1"

  # Host is a single-node PVE 9.2.20 (kernel 7.0.14-17-pve) on an Intel N100.
  # vmbr0 192.168.89.254/24 gw 192.168.89.1, bridge-ports enp1s0 enp3s0.
  # Storage: dir local (/var/lib/vz), lvmthin local-lvm (vg pve, thinpool data).
  # No QEMU guests. Do not manage the bridge or datastores here — a bad apply drops the host.

  # Debian 13 template already on the node. Used only as the import placeholder.
  # ignore_changes on template_file_id so plan does not reinstall a running rootfs.
  debian_template = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
}
