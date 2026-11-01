# Public DNS for Traefik IngressRoute Host() names is owned by external-dns
# (kubernetes/networking/external-dns): Cloudflare A → WAN IP (ConfigMap wan-ip),
# AdGuard dnsrewrite → 192.168.89.252.
#
# Do not recreate *.dominiksiejak.pl. That wildcard sent every
# <garbage>.dominiksiejak.pl (including DHCP search-domain retries) to Traefik.
# Delete the live record once before or right after enabling external-dns sync:
#   make -C tofu/cloudflare delete-apex-wildcard-dns CF_API_TOKEN=…
