resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  backend              = vault_auth_backend.kubernetes.path
  kubernetes_host      = "https://kubernetes.default.svc:443"
  disable_local_ca_jwt = false
}

resource "vault_kubernetes_auth_backend_role" "eso_openbao" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "eso-openbao"
  bound_service_account_names      = ["eso-openbao"]
  bound_service_account_namespaces = ["external-secrets"]
  token_policies                   = [vault_policy.eso_read.name]
  token_ttl                        = 3600
}
