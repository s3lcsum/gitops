locals {
  # Hosts Grafana Cloud public probes may hit. Tunnel already routes these
  # to Traefik. WAF country rule still blocks probe source countries.
  synthetic_probe_hosts = [
    "auth.dominiksiejak.pl",
    "hass.dominiksiejak.pl",
    "n8n.dominiksiejak.pl",
  ]

  # Grafana Cloud prod-us-central-0 egress (allowlists.us.grafana.net/v1/grafana).
  # These are the source IPs of Hosted Grafana back-channel calls (OAuth token,
  # userinfo, alert webhooks). They change; refresh from that URL when login
  # from Grafana Cloud starts failing with a Cloudflare country block.
  grafana_cloud_us_egress = [
    "34.69.204.106/32",
    "107.178.208.235/32",
    "35.223.104.30/32",
    "34.122.201.10/32",
    "35.194.53.190/32",
    "34.70.10.78/32",
    "104.154.18.168/32",
    "35.192.170.84/32",
    "35.225.46.237/32",
    "35.238.91.227/32",
    "35.239.61.132/32",
    "104.154.148.31/32",
    "23.236.55.100/32",
    "34.71.21.236/32",
    "104.154.179.160/32",
    "35.202.43.115/32",
    "104.197.149.206/32",
    "35.222.253.67/32",
    "34.122.25.189/32",
    "35.184.23.28/32",
    "34.72.240.165/32",
    "34.70.19.238/32",
    "34.68.98.63/32",
    "35.188.111.61/32",
    "35.188.211.52/32",
    "34.134.222.119/32",
    "35.192.9.186/32",
    "34.72.94.67/32",
    "35.223.234.104/32",
    "34.71.146.82/32",
    "34.71.98.16/32",
    "34.134.236.18/32",
    "35.232.101.234/32",
    "34.69.227.129/32",
    "34.69.89.218/32",
    "34.121.249.58/32",
    "35.188.35.239/32",
    "35.224.49.153/32",
    "35.224.152.225/32",
    "35.193.153.9/32",
    "35.188.223.159/32",
    "34.121.8.98/32",
    "35.232.52.64/32",
    "104.197.203.224/32",
    "35.232.164.62/32",
    "34.132.169.54/32",
    "34.67.217.87/32",
    "34.133.189.12/32",
    "35.193.116.27/32",
    "35.239.142.182/32",
    "34.71.213.69/32",
    "34.68.102.192/32",
    "34.136.227.230/32",
    "35.224.213.187/32",
    "104.197.72.38/32",
    "35.225.14.197/32",
    "34.28.196.162/32",
    "34.66.50.58/32",
    "34.30.244.87/32",
    "34.66.84.48/32",
    "130.211.200.28/32",
    "104.198.217.90/32",
    "34.122.77.65/32",
    "34.31.90.160/32",
  ]

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
          # TLS to origin: cloudflared connects to container `traefik` but SNI/verification
          # must use the public hostname so Traefik serves the wildcard *.dominiksiejak.pl cert.
          origin_server_name = host
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
