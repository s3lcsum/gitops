# =============================================================================
# PKI Secrets Engine - Internal CA for TLS certificates
# =============================================================================

# Root CA PKI mount
resource "vault_mount" "pki_root" {
  path                      = "pki"
  type                      = "pki"
  description               = "Root CA for internal services"
  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds     = 315360000 # 10 years
}

# Generate Root CA
resource "vault_pki_secret_backend_root_cert" "root" {
  backend     = vault_mount.pki_root.path
  type        = "internal"
  common_name = local.pki.root_ca.common_name
  ttl         = local.pki.root_ca.ttl
  key_type    = "rsa"
  key_bits    = 4096

  organization = "Homelab"
  country      = "PL"
}

# Configure Root CA URLs
resource "vault_pki_secret_backend_config_urls" "root" {
  backend = vault_mount.pki_root.path

  issuing_certificates = [
    "{{cluster_aia_path}}/issuer/{{issuer_id}}/der"
  ]
  crl_distribution_points = [
    "{{cluster_aia_path}}/issuer/{{issuer_id}}/crl/der"
  ]
  ocsp_servers = [
    "{{cluster_path}}/ocsp"
  ]
  enable_templating = true
}

resource "vault_pki_secret_backend_config_cluster" "root" {
  backend  = vault_mount.pki_root.path
  path     = "${var.vault_address}/v1/${vault_mount.pki_root.path}"
  aia_path = "${var.vault_address}/v1/${vault_mount.pki_root.path}"

  depends_on = [vault_pki_secret_backend_config_urls.root]
}

# Intermediate CA PKI mount
resource "vault_mount" "pki_intermediate" {
  path                        = "pki_int"
  type                        = "pki"
  description                 = "Intermediate CA for issuing certificates"
  default_lease_ttl_seconds   = 3600
  max_lease_ttl_seconds       = 157680000 # 5 years
  passthrough_request_headers = ["If-Modified-Since"]
  allowed_response_headers    = ["Last-Modified", "Location", "Replay-Nonce", "Link"]
}

# Generate Intermediate CA CSR
resource "vault_pki_secret_backend_intermediate_cert_request" "intermediate" {
  backend     = vault_mount.pki_intermediate.path
  type        = "internal"
  common_name = local.pki.intermediate_ca.common_name
  key_type    = "rsa"
  key_bits    = 4096
}

# Sign Intermediate CA with Root CA
resource "vault_pki_secret_backend_root_sign_intermediate" "intermediate" {
  backend     = vault_mount.pki_root.path
  common_name = local.pki.intermediate_ca.common_name
  csr         = vault_pki_secret_backend_intermediate_cert_request.intermediate.csr
  ttl         = local.pki.intermediate_ca.ttl

  organization = "Homelab"
  country      = "PL"
}

# Set Intermediate CA certificate
resource "vault_pki_secret_backend_intermediate_set_signed" "intermediate" {
  backend     = vault_mount.pki_intermediate.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.intermediate.certificate
}

# Configure Intermediate CA URLs
resource "vault_pki_secret_backend_config_urls" "intermediate" {
  backend = vault_mount.pki_intermediate.path

  issuing_certificates = [
    "{{cluster_aia_path}}/issuer/{{issuer_id}}/der"
  ]
  crl_distribution_points = [
    "{{cluster_aia_path}}/issuer/{{issuer_id}}/crl/der"
  ]
  ocsp_servers = [
    "{{cluster_path}}/ocsp"
  ]
  enable_templating = true
}

resource "vault_pki_secret_backend_config_cluster" "intermediate" {
  backend  = vault_mount.pki_intermediate.path
  path     = "${var.vault_address}/v1/${vault_mount.pki_intermediate.path}"
  aia_path = "${var.vault_address}/v1/${vault_mount.pki_intermediate.path}"

  depends_on = [vault_pki_secret_backend_config_urls.intermediate]
}

# PKI roles (intermediate CA)
resource "vault_pki_secret_backend_role" "internal_services" {
  backend = vault_mount.pki_intermediate.path
  name    = "internal-services"

  allowed_domains    = local.pki.allowed_domains
  allow_subdomains   = true
  allow_bare_domains = true
  allow_glob_domains = true
  allow_localhost    = true
  allow_ip_sans      = true

  key_type  = "rsa"
  key_bits  = 2048
  key_usage = ["DigitalSignature", "KeyEncipherment"]

  max_ttl = local.pki.max_ttl     # 17280
  ttl     = local.pki.default_ttl # 720

  generate_lease = true
}

resource "vault_pki_secret_backend_role" "server_certs" {
  backend = vault_mount.pki_intermediate.path
  name    = "server-certs"

  allowed_domains    = local.pki.allowed_domains
  allow_subdomains   = true
  allow_bare_domains = true
  allow_glob_domains = true
  allow_localhost    = true
  allow_ip_sans      = true

  key_type            = "rsa"
  key_bits            = 2048
  key_usage           = ["DigitalSignature", "KeyEncipherment"]
  ext_key_usage       = ["ServerAuth"]
  server_flag         = true
  client_flag         = false
  require_cn          = true
  use_csr_common_name = true

  max_ttl = 31536000 # match existing
  ttl     = 7776000  # match existing (2160h)

  generate_lease = true
}

resource "vault_pki_secret_backend_role" "client_certs" {
  backend = vault_mount.pki_intermediate.path
  name    = "client-certs"

  allowed_domains  = local.pki.allowed_domains
  allow_subdomains = true
  allow_any_name   = true
  allow_ip_sans    = true

  key_type      = "rsa"
  key_bits      = 2048
  key_usage     = ["DigitalSignature"]
  ext_key_usage = ["ClientAuth"]
  server_flag   = false
  client_flag   = true

  max_ttl = local.pki.max_ttl     # 17280
  ttl     = local.pki.default_ttl # 720

  generate_lease = true
}

resource "vault_pki_secret_backend_role" "acme" {
  backend = vault_mount.pki_intermediate.path
  name    = "acme"

  allowed_domains    = local.pki.allowed_domains
  allow_subdomains   = true
  allow_bare_domains = true
  allow_glob_domains = true
  allow_any_name     = true

  key_type      = "rsa"
  key_bits      = 2048
  key_usage     = ["DigitalSignature", "KeyEncipherment"]
  ext_key_usage = ["ServerAuth"]
  server_flag   = true
  client_flag   = false

  max_ttl = local.pki.max_ttl     # 17280
  ttl     = local.pki.default_ttl # 720
}

# Enable ACME on the intermediate CA
resource "vault_generic_endpoint" "pki_intermediate_acme" {
  path                 = "${vault_mount.pki_intermediate.path}/config/acme"
  disable_read         = false
  disable_delete       = true
  ignore_absent_fields = true

  data_json = jsonencode({
    enabled = true
  })

  depends_on = [
    vault_pki_secret_backend_intermediate_set_signed.intermediate,
    vault_pki_secret_backend_config_cluster.intermediate
  ]
}
