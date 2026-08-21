# Account-scoped API token granting exactly the permissions this module's
# resources need (zone, DNS records, zone ruleset, Zero Trust access apps,
# Zero Trust tunnels). Values verified against the account's permission groups.
resource "cloudflare_account_token" "terraform" {
  account_id = var.cloudflare_account_id
  name       = "gitops terraform (cloudflare module)"

  policies = [{
    effect = "allow"
    permission_groups = [
      { id = "c8fed203ed3043cba015a93ad1616f1f" }, # Zone Read
      { id = "e6d2666161e84845a636613608cee8d5" }, # Zone Write
      { id = "82e64a83756745bbbb1c9c2701bf816b" }, # DNS Read
      { id = "4755a26eedb94da69e1066d98aa820be" }, # DNS Write
      { id = "fb39996ee9044d2a8725921e02744b39" }, # Account Rulesets Read
      { id = "56907406c3d548ed902070ec4df0e328" }, # Account Rulesets Write
      { id = "959972745952452f8be2452be8cbb9f2" }, # Access: Apps and Policies Write
      { id = "1e13c5124ca64b72b1969a67e8829049" }, # Access: Apps and Policies Write
      { id = "eb258a38ea634c86a0c89da6b27cb6b6" }, # Access: Apps and Policies Read
      { id = "efea2ab8357b47888938f101ae5e053f" }, # Cloudflare Tunnel Read
      { id = "c07321b023e944ff818fec44d8203567" }, # Cloudflare Tunnel Write
    ]
    resources = jsonencode({
      "com.cloudflare.api.account.${var.cloudflare_account_id}" = "*"
    })
  }]
}

output "terraform_token" {
  description = "Cloudflare API token minted for Terraform (sensitive)."
  value       = cloudflare_account_token.terraform.value
  sensitive   = true
}
