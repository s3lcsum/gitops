# Classic AdGuard DNS rewrites (/control/rewrite/*) — not external-dns $dnsrewrite user rules.
#
# IngressRoute Host() names → external-dns-adguard (DNSEndpoint bridge → .252). Do not duplicate here.
# Keep only: non-.252 targets, HostSNI-only routes (bridge parses Host() only), no IngressRoute.
#
# Requires external-dns-adguard out of dry-run before dropping a name that still needs LAN resolution.
locals {
  rewrites = {
    "lake.dominiksiejak.pl"     = "192.168.89.254"
    "vibe.dominiksiejak.pl"     = "192.168.89.200"
    "vibe-k8s.dominiksiejak.pl" = "192.168.89.201"
    "k8s.dominiksiejak.pl"      = "192.168.89.252" # Traefik HostSNI, not Host()
    "status.dominiksiejak.pl"   = "192.168.89.252" # no IngressRoute in gitops
  }
}
