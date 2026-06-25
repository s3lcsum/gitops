output "tunnel_id" {
  description = "Cloudflare Tunnel UUID"
  value       = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}

output "tunnel_token" {
  description = "Cloudflared tunnel token (sensitive). Place this in stacks/cloudflared/cloudflared.env as TUNNEL_TOKEN."
  value       = cloudflare_zero_trust_tunnel_cloudflared.homelab.tunnel_token
  sensitive   = true
}

output "active_apps" {
  description = "List of hostnames currently configured on the tunnel"
  value       = keys(local.active_apps)
}
