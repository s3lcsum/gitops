output "tunnel_id" {
  description = "Cloudflare Tunnel UUID"
  value       = cloudflare_zero_trust_tunnel_cloudflared.Lake.id
}

output "tunnel_secret" {
  description = "Cloudflare Tunnel registration secret (sensitive). Used as the connector credential for cloudflared."
  value       = cloudflare_zero_trust_tunnel_cloudflared.Lake.tunnel_secret
  sensitive   = true
}

output "active_apps" {
  description = "List of hostnames currently configured on the tunnel"
  value       = keys(local.active_apps)
}

output "miedzysztuka_hostname" {
  description = "Public hostname for the miedzysztuka Pages custom domain"
  value       = cloudflare_pages_domain.miedzysztuka.name
}
