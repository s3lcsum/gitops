# Public DNS for most Traefik IngressRoute Host() names: external-dns-cloudflare (A → WAN),
# external-dns-adguard (dnsrewrite → 192.168.89.252).
#
# auth / hass / n8n: tunnel-only — proxied CNAME + ingress in this module (tunnel_apps).
# external-dns excludes them so it does not fight those records or split-horizon rewrites.
#
# Do not recreate *.dominiksiejak.pl. That wildcard sent every
# <garbage>.dominiksiejak.pl (including DHCP search-domain retries) to Traefik.
# Delete the live record once before or right after enabling external-dns sync:
#   Delete legacy *.dominiksiejak.pl A in Cloudflare (Zone DNS Edit) if present.
