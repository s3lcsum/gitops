# Non-secret defaults. Secret: local.secret.cloudflare_api_token (ephemeral).
locals {
  cfg = {
    cloudflare_account_id = "e092ee6780d8a561afd1530702c0fd6a"
    zone_name             = "dominiksiejak.pl"
    tunnel_name           = "homelab"
    tunnel_team_name      = "dominiksiejak"
    # tunnel_apps: Zero Trust ingress + proxied CNAME (tofu). https:// → Access JWT + HTTPS origin.
    # auth/hass/n8n: tunnel-only (excluded from external-dns in kubernetes/networking/external-dns).
    # Other Traefik IngressRoute hosts: WAN A (external-dns-cloudflare) + dnsrewrite @ .252 (adguard).
    tunnel_apps = {
      "homeassistant-atom.dominiksiejak.pl" = ""
      "dns.dominiksiejak.pl"                = ""
      "auth.dominiksiejak.pl"               = "https://traefik"
      "hass.dominiksiejak.pl"               = "https://traefik"
      "n8n.dominiksiejak.pl"                = "https://traefik"
    }
    # Zoho Mail EU (smtp.zoho.eu) signs mail.dominiksiejak.pl — Authentik recovery, etc.
    # Admin Console → Domains → mail.dominiksiejak.pl → Email Configuration → DKIM:
    # copy TXT value (v=DKIM1; …) here, then apply and Enable the selector in Zoho.
    zoho_dkim_selector = "root"
    zoho_dkim_txt      = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqZqOx54wJfrref+nz7EA0isX+IeXHBMRkAwTfB7Te+RTBy1NODtDqjT6noVTeNMngXu2xHmUEW3pXAA0/pG5lLrKITnPU6KWcQuWsqty9PzkEamILlAlF5tfMPgoJM+bBZg3Aj0DulMqmKg8gK5W0sm7JrRcwrAhO0IXlNQapRhHmlukWaPI65A6b6RcQj+n2AFyTx7y39MxeOn1a3h6pOVpffxYcG8Gjg2x53sYwP3TMXuhIAyyzoVRHczgXrH2YKDD7BjRdVzSgPWmlFqDRb+U0je+5n6uxvW9U3g1jmizIgRFG9DLg5yu6QkUGXOdXQM7HF431Tb04Gk3m+trxwIDAQAB"
  }
}
