# /ip/dns/static — LAN names RouterOS answers when clients query the router (not AdGuard).
# IngressRoute Host() names also sync to AdGuard via external-dns-adguard (.252); keep targets aligned.
locals {
  traefik_lake = "192.168.89.252"

  dns_records = {
    netbox = {
      name    = "netbox.dominiksiejak.pl"
      address = local.traefik_lake
      type    = "A"
      comment = "gitops | Traefik | netbox"
    }
  }
}

resource "routeros_ip_dns_record" "records" {
  for_each = local.dns_records

  name    = each.value.name
  address = each.value.address
  type    = each.value.type
  comment = each.value.comment
}
