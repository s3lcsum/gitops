locals {
  # Only create ingress rules / DNS records for apps whose origin is explicitly set.
  active_apps = {
    for host, origin in var.tunnel_apps : host => origin
    if origin != "" && origin != null
  }

  # Public HTTP(S) hosts that require a Cloudflare Access JWT assertion at the
  # connector (origin_request.access). Identified by an https:// origin.
  web_apps = {
    for host, origin in local.active_apps : host => origin
    if startswith(origin, "https")
  }

  # Non-web (TCP) active apps — routed but not JWT-gated.
  tcp_apps = {
    for host, origin in local.active_apps : host => origin
    if !startswith(origin, "https")
  }

  # Complete ingress list for the tunnel config (5.22.0 value-form `config.ingress`).
  # Web hosts get the Access JWT gate; TCP hosts get plain hostname/service;
  # a trailing catch-all returns 404 for unmatched hostnames.
  tunnel_ingress = concat(
    [
      for host, origin in local.web_apps : {
        hostname = host
        service  = origin
        origin_request = {
          access = {
            required  = true
            aud_tag   = [cloudflare_zero_trust_access_application.tunnel[host].aud]
            team_name = var.tunnel_team_name
          }
        }
      }
    ],
    [
      for host, origin in local.tcp_apps : {
        hostname = host
        service  = origin
      }
    ],
    [
      {
        service = "http_status:404"
      }
    ]
  )
}
