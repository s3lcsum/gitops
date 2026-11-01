resource "vault_mount" "pki_int_servers" {
  path                      = "pki_int_servers"
  type                      = "pki"
  description               = "Homelab server intermediate (leaf issue)"
  default_lease_ttl_seconds = 86400
  max_lease_ttl_seconds     = 157680000 # 5y
}

resource "vault_mount" "pki_int_clients" {
  path                      = "pki_int_clients"
  type                      = "pki"
  description               = "Homelab client intermediate (mTLS leaf issue)"
  default_lease_ttl_seconds = 86400
  max_lease_ttl_seconds     = 157680000
}

# After first apply fails on "path already in use", import:
#   tofu import vault_mount.pki_int_servers pki_int_servers
#   tofu import vault_mount.pki_int_clients pki_int_clients

# ttl / max_ttl are seconds, not "2160h" strings. The Vault API stores and
# returns seconds, so an "8760h" literal plans as a change forever.
#   720h  = 2592000  (30d)    2160h = 7776000  (90d)    8760h = 31536000 (1y)

resource "vault_pki_secret_backend_role" "server_ip" {
  backend            = vault_mount.pki_int_servers.path
  name               = "server-ip"
  ttl                = "31536000"
  max_ttl            = "31536000"
  allow_any_name     = true
  allow_ip_sans      = true
  require_cn         = false
  key_type           = "ec"
  key_bits           = 256
  allowed_domains    = []
  allow_bare_domains = false
  allow_subdomains   = false
  # CN is label only (e.g. common_name=proxmox-lan); actual IP goes in ip_sans=192.168.89.254
  allowed_uri_sans = []
  server_flag      = true
  client_flag      = false
}

resource "vault_pki_secret_backend_role" "server_dns" {
  backend            = vault_mount.pki_int_servers.path
  name               = "server-dns"
  ttl                = "7776000"
  max_ttl            = "7776000"
  allow_any_name     = false
  enforce_hostnames  = true
  allow_bare_domains = true
  allow_subdomains   = true
  allowed_domains    = ["dominiksiejak.pl"]
  key_type           = "ec"
  key_bits           = 256
  server_flag        = true
  client_flag        = false
}

# Internal cluster TLS: cert-manager mints one wildcard per namespace
# (*.<ns>.svc.cluster.local). Both EKUs so pods can serve and present mTLS.
resource "vault_pki_secret_backend_role" "server_internal" {
  backend                     = vault_mount.pki_int_servers.path
  name                        = "server-internal"
  ttl                         = "2592000"
  max_ttl                     = "7776000"
  allow_any_name              = false
  enforce_hostnames           = false
  require_cn                  = false # cert-manager signs CSRs with SANs only
  allow_bare_domains          = true
  allow_subdomains            = true
  allow_wildcard_certificates = true
  allow_ip_sans               = false
  allowed_domains             = ["svc", "svc.cluster.local", "pod.cluster.local", "cluster.local", "dominiksiejak.pl"]
  key_type                    = "ec"
  key_bits                    = 256
  server_flag                 = true
  client_flag                 = true
}

resource "vault_pki_secret_backend_role" "client_device" {
  backend        = vault_mount.pki_int_clients.path
  name           = "client-device"
  ttl            = "31536000"
  max_ttl        = "31536000"
  allow_any_name = true
  require_cn     = true
  key_type       = "ec"
  key_bits       = 256
  server_flag    = false
  client_flag    = true
  organization   = ["dominiksiejak.pl"]
}

resource "vault_pki_secret_backend_role" "client_user" {
  backend            = vault_mount.pki_int_clients.path
  name               = "client-user"
  ttl                = "7776000"
  max_ttl            = "7776000"
  allow_any_name     = false
  allowed_domains    = ["dominiksiejak.pl"]
  allow_bare_domains = true
  enforce_hostnames  = false
  key_type           = "ec"
  key_bits           = 256
  server_flag        = false
  client_flag        = true
  # Issue with common_name=<user> alt_names=<email>
}
