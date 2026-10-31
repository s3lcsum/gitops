# OpenBao PKI + mTLS Pilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a 10y private PKI on OpenBao (root outside tofu state, server + client intermediates), wire cert-manager + Traefik mTLS demo + Cloudflare country bypass via client cert, and issue one Proxmox IP leaf — without flipping live Authentik TLS off Let’s Encrypt.

**Architecture:** Bootstrap creates `pki_root` + signed `pki_int_servers` / `pki_int_clients` with break-glass root token. `tofu/openbao` owns roles, policies, and Kubernetes auth for cert-manager. Pilot edges: Proxmox `192.168.89.254:8006` server leaf; `Certificate` `auth-openbao-tls` (not attached); Traefik `mtls-demo.dominiksiejak.pl` + `TLSOption` `mtls-strict`; Cloudflare Access mTLS CA + WAF skip on `cf.tls_client_auth.cert_verified` for `hass.dominiksiejak.pl` (fully country-gated today).

**Tech Stack:** OpenBao (vault provider `5.13.0`), OpenTofu `>= 1.11.5` / pin `1.12.5`, cert-manager `v1.21.3` Vault ClusterIssuer, Traefik CRDs (`TLSOption` / `IngressRoute`), Cloudflare provider Access mTLS + ruleset, AdGuard rewrites.

**Spec:** `docs/superpowers/specs/2026-10-31-openbao-pki-mtls-design.md`

## Global Constraints

- OpenTofu, not Terraform; pin providers to exact versions (never `~>`)
- Day-2 OpenBao API config lives in `tofu/openbao` (GCS prefix `gitops-openbao`); never recreate Terrakube
- Never put root private key in git, 1Password field dumps in commits, or tofu state — only CA PEMs
- Do not create `vault_pki_secret_backend_root_cert` in tofu
- Do not point Authentik IngressRoute at `auth-openbao-tls` in this plan
- Do not enable origin-pull mTLS on cloudflared (incompatible with named tunnels)
- Do not grant ESO leaf-issue on PKI paths
- Prefer control-plane / existing priorityClass patterns; Traefik pilot stays in `traefik` namespace
- Auth class file was removed from repo; skip `scripts/auth_classification.yaml` (host still documented in Traefik route comment: `lan-only` / mTLS)

## File map

| Path | Role |
|------|------|
| `kubernetes/platform/openbao/resources/bootstrap-notes.yaml` | PKI bootstrap runbook (root + ints) |
| `tofu/openbao/pki.tf` | Mount imports or URL config + four PKI roles |
| `tofu/openbao/policies.tf` | `pki-cert-manager`, `pki-operator` |
| `tofu/openbao/auth_kubernetes.tf` | Role `cert-manager` |
| `kubernetes/platform/cert-manager/resources/clusterissuer-openbao.yaml` | Vault ClusterIssuer |
| `kubernetes/platform/cert-manager/resources/certificate-auth-openbao.yaml` | Pilot Certificate (unused by Ingress) |
| `kubernetes/platform/cert-manager/kustomization.yaml` | List new resources |
| `kubernetes/networking/traefik/resources/mtls/` | CA secret, TLSOption, whoami, route |
| `kubernetes/networking/traefik/kustomization.yaml` | Wire mtls resources |
| `tofu/adguard/locals.tf` | Rewrite `mtls-demo.dominiksiejak.pl` |
| `tofu/cloudflare/mtls.tf` | Access mTLS CA + variables |
| `tofu/cloudflare/main.tf` | WAF skip for verified client cert on hass |

---

### Task 1: PKI bootstrap runbook (root + intermediates)

**Files:**
- Modify: `kubernetes/platform/openbao/resources/bootstrap-notes.yaml`

**Interfaces:**
- Consumes: existing OpenBao unsealed + root-token in 1Password
- Produces: mounts `pki_root`, `pki_int_servers`, `pki_int_clients`; root CA PEM in 1Password; intermediate CA PEMs available at `/v1/<mount>/ca`

- [ ] **Step 1: Append section `## 5. PKI bootstrap (once)` to RUNBOOK.md**

Exact commands (run with root token; prefer `kubectl exec -n openbao openbao-0 -- env BAO_TOKEN=... bao ...` or local `bao` against `https://openbao.dominiksiejak.pl`):

```bash
# --- root ---
bao secrets enable -path=pki_root pki
bao secrets tune -max-lease-ttl=87600h pki_root
bao write -field=certificate pki_root/root/generate/internal \
  common_name="Dominik Siejak Homelab Root CA" \
  organization="dominiksiejak.pl" \
  ttl=87600h > /tmp/homelab-root-ca.crt
bao write pki_root/config/urls \
  issuing_certificates="https://openbao.dominiksiejak.pl/v1/pki_root/ca" \
  crl_distribution_points="https://openbao.dominiksiejak.pl/v1/pki_root/crl"

# Store /tmp/homelab-root-ca.crt in 1Password (Servers/openbao field root-ca-pem). Install on test device later.

# --- server intermediate ---
bao secrets enable -path=pki_int_servers pki
bao secrets tune -max-lease-ttl=43800h pki_int_servers
bao write -format=json pki_int_servers/intermediate/generate/internal \
  common_name="Dominik Siejak Homelab Servers Intermediate" \
  organization="dominiksiejak.pl" \
  ttl=43800h | jq -r '.data.csr' > /tmp/servers.csr
bao write -format=json pki_root/root/sign-intermediate csr=@/tmp/servers.csr \
  format=pem_bundle ttl=43800h | jq -r '.data.certificate' > /tmp/servers-int.crt
bao write pki_int_servers/intermediate/set-signed certificate=@/tmp/servers-int.crt
bao write pki_int_servers/config/urls \
  issuing_certificates="https://openbao.dominiksiejak.pl/v1/pki_int_servers/ca" \
  crl_distribution_points="https://openbao.dominiksiejak.pl/v1/pki_int_servers/crl"

# --- client intermediate ---
bao secrets enable -path=pki_int_clients pki
bao secrets tune -max-lease-ttl=43800h pki_int_clients
bao write -format=json pki_int_clients/intermediate/generate/internal \
  common_name="Dominik Siejak Homelab Clients Intermediate" \
  organization="dominiksiejak.pl" \
  ttl=43800h | jq -r '.data.csr' > /tmp/clients.csr
bao write -format=json pki_root/root/sign-intermediate csr=@/tmp/clients.csr \
  format=pem_bundle ttl=43800h | jq -r '.data.certificate' > /tmp/clients-int.crt
bao write pki_int_clients/intermediate/set-signed certificate=@/tmp/clients-int.crt
bao write pki_int_clients/config/urls \
  issuing_certificates="https://openbao.dominiksiejak.pl/v1/pki_int_clients/ca" \
  crl_distribution_points="https://openbao.dominiksiejak.pl/v1/pki_int_clients/crl"

# Store clients-int (and optionally servers-int) PEM in 1Password for Traefik/Cloudflare.
# shred local key material copies that are not CA-only PEMs.
```

Also document: after Task 2 roles exist, day-2 identities must not use `pki_root/root/sign-intermediate` except break-glass (`pki-operator` / root).

- [ ] **Step 2: Commit runbook only (before live bao if preferred) or after successful bootstrap**

```bash
git add kubernetes/platform/openbao/resources/bootstrap-notes.yaml
git commit -m "$(cat <<'EOF'
docs(openbao): PKI bootstrap runbook for root + dual intermediates.

EOF
)"
```

- [ ] **Step 3: Execute bootstrap against live OpenBao; verify**

```bash
bao read -field=certificate pki_root/cert/ca | openssl x509 -noout -subject -dates
bao read -field=certificate pki_int_servers/cert/ca | openssl x509 -noout -subject -dates
bao read -field=certificate pki_int_clients/cert/ca | openssl x509 -noout -subject -dates
```

Expected: root CN `Dominik Siejak Homelab Root CA`, notAfter ~10y; ints ~5y; ints chain to root (`openssl verify -CAfile root.crt int.crt` → OK).

---

### Task 2: tofu PKI roles + policies + cert-manager K8s auth

**Files:**
- Create: `tofu/openbao/pki.tf`
- Modify: `tofu/openbao/policies.tf`
- Modify: `tofu/openbao/auth_kubernetes.tf`

**Interfaces:**
- Consumes: mounts from Task 1 already enabled
- Produces: roles `server-ip`, `server-dns`, `client-device`, `client-user`; policies `pki-cert-manager`, `pki-operator`; k8s auth role `cert-manager`

- [ ] **Step 1: Add `pki.tf` (roles only — no root cert resource)**

```hcl
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

resource "vault_pki_secret_backend_role" "server_ip" {
  backend          = vault_mount.pki_int_servers.path
  name             = "server-ip"
  ttl              = "8760h"
  max_ttl          = "8760h"
  allow_any_name   = false
  allow_ip_sans    = true
  require_cn       = false
  key_type         = "ec"
  key_bits         = 256
  allowed_domains  = []
  allow_bare_domains = false
  allow_subdomains = false
  # Issue with ip_sans=192.168.89.254 common_name=proxmox-lan
  allowed_uri_sans = []
  server_flag      = true
  client_flag      = false
}

resource "vault_pki_secret_backend_role" "server_dns" {
  backend            = vault_mount.pki_int_servers.path
  name               = "server-dns"
  ttl                = "2160h"
  max_ttl            = "2160h"
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

resource "vault_pki_secret_backend_role" "client_device" {
  backend          = vault_mount.pki_int_clients.path
  name             = "client-device"
  ttl              = "8760h"
  max_ttl          = "8760h"
  allow_any_name   = true
  require_cn       = true
  key_type         = "ec"
  key_bits         = 256
  server_flag      = false
  client_flag      = true
  organization     = ["dominiksiejak.pl"]
}

resource "vault_pki_secret_backend_role" "client_user" {
  backend            = vault_mount.pki_int_clients.path
  name               = "client-user"
  ttl                = "2160h"
  max_ttl            = "2160h"
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
```

If `server_ip` rejects empty `allowed_domains`, set `allow_any_name = true` with `allow_ip_sans = true` and document CN as label only (IP in `ip_sans`).

- [ ] **Step 2: Add policies to `policies.tf`**

```hcl
resource "vault_policy" "pki_cert_manager" {
  name = "pki-cert-manager"

  policy = <<-EOT
    path "pki_int_servers/sign/server-dns" {
      capabilities = ["create", "update"]
    }
    path "pki_int_servers/issue/server-dns" {
      capabilities = ["create", "update"]
    }
    path "pki_int_servers/ca" {
      capabilities = ["read"]
    }
    path "pki_int_servers/ca_chain" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_policy" "pki_operator" {
  name = "pki-operator"

  policy = <<-EOT
    path "pki_int_servers/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "pki_int_clients/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "pki_root/cert/*" {
      capabilities = ["read", "list"]
    }
    path "pki_root/ca" {
      capabilities = ["read"]
    }
  EOT
}
```

Do **not** grant `pki_root/root/*` on `pki-operator` (break-glass root token only for re-signing ints).

- [ ] **Step 3: Add kubernetes auth role in `auth_kubernetes.tf`**

```hcl
resource "vault_kubernetes_auth_backend_role" "cert_manager" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "cert-manager"
  bound_service_account_names      = ["cert-manager"]
  bound_service_account_namespaces = ["cert-manager"]
  token_policies                   = [vault_policy.pki_cert_manager.name]
  token_ttl                        = 600
}
```

- [ ] **Step 4: Plan / import / apply**

```bash
cd tofu/openbao
make check
tofu plan
# if mounts exist:
tofu import 'vault_mount.pki_int_servers' pki_int_servers
tofu import 'vault_mount.pki_int_clients' pki_int_clients
tofu apply
```

Expected: four roles + two policies + k8s role created; no root cert in state (`tofu state list | grep pki` shows mounts/roles only).

- [ ] **Step 5: Smoke-issue server-ip and client-device (operator token)**

```bash
bao write -format=json pki_int_servers/issue/server-ip \
  common_name=proxmox-lan ip_sans=192.168.89.254 ttl=24h \
  | jq -r '.data.certificate' | openssl x509 -noout -ext subjectAltName

bao write -format=json pki_int_clients/issue/client-device \
  common_name=pilot-laptop ttl=24h \
  | jq -r '.data | {cert:.certificate, key:.private_key}'
```

Expected: SAN IP Address `192.168.89.254`; client cert with Client Auth EKU.

- [ ] **Step 6: Commit**

```bash
git add tofu/openbao/pki.tf tofu/openbao/policies.tf tofu/openbao/auth_kubernetes.tf
git commit -m "$(cat <<'EOF'
feat(openbao): PKI roles, policies, and cert-manager K8s auth.

EOF
)"
```

---

### Task 3: cert-manager ClusterIssuer + pilot auth Certificate

**Files:**
- Create: `kubernetes/platform/cert-manager/resources/clusterissuer-openbao.yaml`
- Create: `kubernetes/platform/cert-manager/resources/certificate-auth-openbao.yaml`
- Modify: `kubernetes/platform/cert-manager/kustomization.yaml`

**Interfaces:**
- Consumes: OpenBao role `cert-manager`, path `pki_int_servers/sign/server-dns`
- Produces: ClusterIssuer `openbao-servers`; Certificate → Secret `auth-openbao-tls` in `authentik` (Ready, unused by IngressRoute)

- [ ] **Step 1: Create ClusterIssuer**

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: openbao-servers
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  vault:
    path: pki_int_servers/sign/server-dns
    server: https://openbao.dominiksiejak.pl
    caBundle: "" # if OpenBao serves public LE via Traefik, leave empty; else embed OpenBao TLS CA
    auth:
      kubernetes:
        role: cert-manager
        mountPath: /v1/auth/kubernetes
        secretRef:
          name: cert-manager-openbao-token
          key: token
```

- [ ] **Step 2: Create SA token Secret for cert-manager (same file or sibling)**

cert-manager chart SA is `cert-manager` in ns `cert-manager`. Prefer projected token Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cert-manager-openbao-token
  namespace: cert-manager
  annotations:
    kubernetes.io/service-account.name: cert-manager
type: kubernetes.io/service-account-token
```

(If cluster disables auto token secrets, switch to cert-manager `serviceAccountRef` if available on 1.21 — verify before apply; otherwise create TokenRequest manually.)

- [ ] **Step 3: Pilot Certificate (do not change Authentik IngressRoute)**

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: auth-openbao
  namespace: authentik
spec:
  secretName: auth-openbao-tls
  duration: 2160h
  renewBefore: 360h
  commonName: auth.dominiksiejak.pl
  dnsNames:
    - auth.dominiksiejak.pl
  issuerRef:
    name: openbao-servers
    kind: ClusterIssuer
```

- [ ] **Step 4: Wire kustomization**

Add both YAML paths under `resources:` in `kubernetes/platform/cert-manager/kustomization.yaml`.

- [ ] **Step 5: Sync / verify**

```bash
kubectl get clusterissuer openbao-servers
kubectl -n authentik get certificate auth-openbao
kubectl -n authentik get secret auth-openbao-tls
openssl x509 -in <(kubectl -n authentik get secret auth-openbao-tls -o jsonpath='{.data.tls\.crt}' | base64 -d) -noout -issuer -subject
```

Expected: Issuer Ready; Certificate Ready; issuer is Servers Intermediate (not LE). Authentik IngressRoute still `tls: {}` (LE default store).

- [ ] **Step 6: Commit**

```bash
git add kubernetes/platform/cert-manager/
git commit -m "$(cat <<'EOF'
feat(cert-manager): OpenBao Vault issuer and pilot auth certificate.

EOF
)"
```

---

### Task 4: Traefik mTLS demo (`mtls-demo`)

**Files:**
- Create: `kubernetes/networking/traefik/resources/mtls/ca-secret.yaml` (or ExternalSecret from 1Password client-int PEM)
- Create: `kubernetes/networking/traefik/resources/mtls/tlsoption.yaml`
- Create: `kubernetes/networking/traefik/resources/mtls/whoami.yaml`
- Create: `kubernetes/networking/traefik/resources/mtls/ingressroute.yaml`
- Modify: `kubernetes/networking/traefik/kustomization.yaml`
- Modify: `tofu/adguard/locals.tf`

**Interfaces:**
- Consumes: client intermediate CA PEM (Task 1); LE still serves server TLS via default TLSStore
- Produces: host `mtls-demo.dominiksiejak.pl` requiring client cert

- [ ] **Step 1: AdGuard rewrite**

In `tofu/adguard/locals.tf` `rewrites` map add:

```hcl
    "mtls-demo.dominiksiejak.pl"        = "192.168.89.252"
```

Apply `tofu/adguard` locally (`make plan` / `make apply`).

- [ ] **Step 2: CA Secret for Traefik clientAuth**

Prefer ExternalSecret from 1Password field `clients-int-ca-pem` → Secret `mtls-client-ca` key `ca.crt` in `traefik` ns. If ESO lag, temporary Opaque Secret is OK for pilot then replace.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mtls-client-ca
  namespace: traefik
type: Opaque
stringData:
  ca.crt: |
    -----BEGIN CERTIFICATE-----
    # paste pki_int_clients CA (or root) PEM — prefer ExternalSecret in final commit
    -----END CERTIFICATE-----
```

Do not commit real PEM. Ship ExternalSecret + empty placeholder documented in bootstrap notes; create live Secret out-of-band first sync.

Recommended ExternalSecret shape (same pattern as crowdsec):

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: mtls-client-ca
  namespace: traefik
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: onepassword
    kind: ClusterSecretStore
  target:
    name: mtls-client-ca
    template:
      data:
        ca.crt: "{{ .ca }}"
  data:
    - secretKey: ca
      remoteRef:
        key: openbao
        property: clients-int-ca-pem
```

Adjust `key`/`property` to match the 1Password item used in Task 1.

- [ ] **Step 3: TLSOption**

```yaml
apiVersion: traefik.io/v1alpha1
kind: TLSOption
metadata:
  name: mtls-strict
  namespace: traefik
spec:
  clientAuth:
    secretNames:
      - mtls-client-ca
    clientAuthType: RequireAndVerifyClientCert
```

- [ ] **Step 4: whoami Deployment + Service**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mtls-whoami
  namespace: traefik
  labels:
    app.kubernetes.io/name: mtls-whoami
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: mtls-whoami
  template:
    metadata:
      labels:
        app.kubernetes.io/name: mtls-whoami
    spec:
      priorityClassName: homelab-low
      containers:
        - name: whoami
          image: traefik/whoami:v1.11.0
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 5m
              memory: 16Mi
---
apiVersion: v1
kind: Service
metadata:
  name: mtls-whoami
  namespace: traefik
spec:
  selector:
    app.kubernetes.io/name: mtls-whoami
  ports:
    - port: 80
      targetPort: 80
```

- [ ] **Step 5: IngressRoute**

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: mtls-demo
  namespace: traefik
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`mtls-demo.dominiksiejak.pl`)
      kind: Rule
      services:
        - name: mtls-whoami
          port: 80
  tls:
    options:
      name: mtls-strict
      namespace: traefik
```

Comment at top: auth class `lan-only` + mTLS; not Cloudflare-tunneled.

- [ ] **Step 6: Wire kustomization + verify**

Add the four resources under `resources/` in `kubernetes/networking/traefik/kustomization.yaml`.

Issue short-lived client cert and test:

```bash
bao write -format=json pki_int_clients/issue/client-device common_name=pilot-curl ttl=24h > /tmp/client.json
jq -r '.data.certificate' /tmp/client.json > /tmp/client.crt
jq -r '.data.private_key' /tmp/client.json > /tmp/client.key
jq -r '.data.ca_chain[]' /tmp/client.json > /tmp/client-chain.crt

curl -vk --cert /tmp/client.crt --key /tmp/client.key https://mtls-demo.dominiksiejak.pl/
# expect HTTP 200 whoami

curl -vk https://mtls-demo.dominiksiejak.pl/
# expect TLS handshake failure / 495-style failure (no client cert)
```

- [ ] **Step 7: Commit**

```bash
git add kubernetes/networking/traefik/ tofu/adguard/locals.tf
git commit -m "$(cat <<'EOF'
feat(traefik): mtls-demo host with RequireAndVerifyClientCert.

EOF
)"
```

---

### Task 5: Cloudflare Access mTLS CA + WAF country skip for hass

**Files:**
- Create: `tofu/cloudflare/mtls.tf`
- Modify: `tofu/cloudflare/main.tf` (`country_allowlist` rules)
- Modify: `tofu/cloudflare/variables.tf` (optional PEM variable)

**Interfaces:**
- Consumes: client intermediate CA PEM (same as Traefik)
- Produces: Access mTLS cert associated with `hass.dominiksiejak.pl`; WAF skip when `cf.tls_client_auth.cert_verified` for that host

**Why hass:** tunnel app already on Traefik; deliberately **not** exempted from country allowlist (unlike auth OIDC / n8n webhooks). Country block is WAF-phase — Access alone cannot bypass it. Skip rule uses verified client cert.

- [ ] **Step 1: Variable for CA PEM (gitignored tfvars)**

```hcl
variable "mtls_client_ca_pem" {
  type        = string
  sensitive   = true
  description = "PEM for pki_int_clients CA uploaded to Cloudflare Access mTLS"
}
```

Add empty placeholder to `defaults.auto.tfvars.example` only (not real PEM).

- [ ] **Step 2: Access mTLS certificate resource (`mtls.tf`)**

```hcl
resource "cloudflare_zero_trust_access_mtls_certificate" "homelab_clients" {
  account_id = var.cloudflare_account_id
  name       = "homelab-openbao-clients"
  certificate = var.mtls_client_ca_pem

  associated_hostnames = [
    "hass.dominiksiejak.pl",
  ]
}
```

- [ ] **Step 3: Prepend WAF skip rule in `country_allowlist` rules list (before block)**

Insert as first rule (or immediately after existing skip rule) so verified mTLS skips the country block:

```hcl
    {
      ref    = "skip-mtls-verified-hass"
      action = "skip"
      expression = "(http.host eq \"hass.dominiksiejak.pl\" and cf.tls_client_auth.cert_verified)"
      description = "Allow OpenBao-issued client certs to bypass country allowlist on hass"
      enabled     = true
      action_parameters = {
        ruleset = "current"
      }
    },
```

Keep existing skip + block rules unchanged otherwise.

- [ ] **Step 4: Plan / apply cloudflare module**

```bash
cd tofu/cloudflare
# put mtls_client_ca_pem in defaults.auto.tfvars (gitignored)
make check
tofu plan
tofu apply
```

Expected: create Access mTLS certificate; update ruleset in place (no tunnel recreation).

- [ ] **Step 5: Verify from a non-PL/DE/ES path (or CF trace)**

With client cert installed in browser/OS for `hass.dominiksiejak.pl`:

```bash
curl -vk --cert /tmp/client.crt --key /tmp/client.key https://hass.dominiksiejak.pl/
```

Expected with cert: not blocked by country rule (200/302/HA login). Without cert from blocked country: country block. From PL without cert: existing behavior (Access non_identity + HA auth).

If `cf.tls_client_auth.cert_verified` stays false with Access-only CA: enable the hostname under Zero Trust / Client Certificates UI for the same CA (document one dashboard click in bootstrap notes) and re-test before inventing new tofu resources.

- [ ] **Step 6: Commit**

```bash
git add tofu/cloudflare/mtls.tf tofu/cloudflare/main.tf tofu/cloudflare/variables.tf tofu/cloudflare/defaults.auto.tfvars.example
git commit -m "$(cat <<'EOF'
feat(cloudflare): OpenBao client CA mTLS and hass country skip.

EOF
)"
```

---

### Task 6: Proxmox IP leaf + device trust checklist

**Files:**
- Modify: `kubernetes/platform/openbao/resources/bootstrap-notes.yaml` (append device install + Proxmox install notes)

**Interfaces:**
- Consumes: role `server-ip`; root CA PEM on device
- Produces: browser trust to `https://192.168.89.254:8006` without warning

- [ ] **Step 1: Issue leaf**

```bash
bao write -format=json pki_int_servers/issue/server-ip \
  common_name=proxmox-lan \
  ip_sans=192.168.89.254 \
  ttl=8760h > /tmp/pve.json
jq -r '.data.certificate' /tmp/pve.json > /tmp/pve.crt
jq -r '.data.private_key' /tmp/pve.json > /tmp/pve.key
jq -r '.data.ca_chain[]' /tmp/pve.json > /tmp/pve-chain.crt
# Combine leaf+chain if Proxmox wants fullchain
cat /tmp/pve.crt /tmp/pve-chain.crt > /tmp/pve-fullchain.crt
```

- [ ] **Step 2: Install on Proxmox**

Use PVE UI (Certificates) or replace `/etc/pve/local/pveproxy-ssl.pem` + `.key` per current PVE docs; restart `pveproxy`. Exact path may vary by PVE version — follow upstream “custom certificate” doc for the running node.

- [ ] **Step 3: Install root CA on one test device**

macOS Keychain (System, Always Trust) / Linux `/usr/local/share/ca-certificates/` + `update-ca-certificates` / iOS/Android profile. Source: 1Password `root-ca-pem`.

- [ ] **Step 4: Verify**

Browser: `https://192.168.89.254:8006` → padlock, no warning.
`openssl s_client -connect 192.168.89.254:8006 -CAfile homelab-root-ca.crt </dev/null` → `Verify return code: 0`.

- [ ] **Step 5: Commit runbook updates only**

```bash
git add kubernetes/platform/openbao/resources/bootstrap-notes.yaml
git commit -m "$(cat <<'EOF'
docs(openbao): device trust and Proxmox leaf install notes.

EOF
)"
```

---

### Task 7: Pilot acceptance gate

**Files:** none (verification only)

- [ ] **Step 1: Run acceptance checklist from spec**

| # | Check | Command / action | Pass? |
|---|--------|------------------|-------|
| 1 | Root on device trusts Proxmox IP | Browser / openssl against `:8006` | |
| 2 | `auth-openbao-tls` Ready; Authentik still LE | `kubectl get certificate -n authentik`; IngressRoute unchanged | |
| 3 | mtls-demo with/without client cert | curl examples in Task 4 | |
| 4 | hass country bypass with client cert | curl/browser from blocked geo or CF rule hit analytics | |
| 5 | No root key in tofu state | `tofu -chdir=tofu/openbao state pull \| grep -i 'BEGIN.*PRIVATE' ` → empty | |

- [ ] **Step 2: Fix any failures before declaring done**

Do not flip Authentik TLS or broaden Cloudflare associations in this plan.

---

## Spec coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| Root outside tofu; 10y | Task 1 |
| Dual intermediates servers/clients | Task 1–2 |
| Roles server-ip/dns, client-device/user | Task 2 |
| Policies + cert-manager k8s auth | Task 2 |
| ClusterIssuer + pilot auth Certificate, no Ingress flip | Task 3 |
| Traefik mtls-demo + TLSOption | Task 4 |
| Cloudflare Access mTLS + country bypass path | Task 5 |
| Proxmox IP leaf + device trust | Task 6 |
| Acceptance | Task 7 |
| No tunnel origin-pull mTLS | Global Constraints |
| No Authentik auto-login wiring | Explicit non-goal / omitted |

## Execution handoff

Plan saved to `docs/superpowers/plans/2026-10-31-openbao-pki-mtls.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks
2. **Inline Execution** — this session, executing-plans with checkpoints

Which approach?
