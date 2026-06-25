locals {
  # Only create ingress rules / DNS records for apps whose origin is explicitly set.
  active_apps = {
    for host, origin in var.tunnel_apps : host => origin
    if origin != "" && origin != null
  }
}
