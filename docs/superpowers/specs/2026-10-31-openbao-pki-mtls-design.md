# OpenBao PKI + mTLS (custom CA) — Design

Date: 2026-10-31
Status: approved for planning (brainstorm decisions locked)

## Goal

Homelab private PKI on OpenBao: 10-year root CA installed on personal devices, used to (1) trust server certs for IP/LAN hosts and optional secondary TLS via cert-manager, and (2) present client certs for mTLS at Traefik and Cloudflare Access (bypass country WAF / prove device trust).

## Decisions (locked)

| Topic | Choice |
| --- | --- |
| Scope | Full stack: OpenBao PKI + cert-manager Issuer + Traefik clientAuth + Cloudflare Access mTLS |
| mTLS edges | Both: Cloudflare Access mTLS + Traefik `clientAuth` |
| Hierarchy | Root + two intermediates: `pki_int_servers`, `pki_int_clients` |
| Client identity | Roles `client-device` (presence) + `client-user` (SAN email/username) |
| Rollout | Pilot only (prove chain; no blanket host cutover) |
| Bootstrap | Root generated outside tofu state; day-2 ints/roles in `tofu/openbao` |

## Non-goals (this effort)

- Replacing Let’s Encrypt as default Traefik TLSStore / public wildcard.
- Cloudflare Tunnel origin-pull mTLS (incompatible with named tunnels; already documented).
- Mapping client cert → Authentik session auto-login in apps (user SAN ready; app wiring later).
- Broad Access policy rewrite or attaching mTLS to every host.
- Putting root private key in GCS OpenTofu state (`gitops-openbao` prefix).

## Architecture

```text
Devices trust: root CA PEM only
                    │
         ┌──────────┴──────────┐
    pki_root (10y)        (sign ints once, then lock)
         │
    ┌────┴────┐
pki_int_servers          pki_int_clients
 server-ip / server-dns   client-device / client-user
         │                      │
   cert-manager + CLI      CLI / device enroll
         │                      │
  Proxmox leaf /            Traefik TLSOption
  auth-* Certificate        Cloudflare Access mTLS CA
```

**Trust model**

- One PEM on every device: root CA.
- Server leafs only from `pki_int_servers`. Client leafs only from `pki_int_clients`.
- After intermediates are signed: revoke root sign capability for day-2 identities (policy + disable generate endpoint usage). Root key remains in OpenBao for rare re-sign of new intermediates; not used for leaf issue.
- Public LE path unchanged until an IngressRoute explicitly sets `tls.secretName` to an OpenBao-issued Secret.

## Components

### 1. OpenBao mounts and roles (`tofu/openbao`)

New files (suggested): `pki.tf`, `pki_policies.tf` (or fold policies into `policies.tf`).

| Mount | Role | Purpose | Default max TTL (pilot) |
| --- | --- | --- | --- |
| `pki_root` | (no leaf roles) | Root CA, TTL ≈ 87600h (10y) | n/a |
| `pki_int_servers` | `server-ip` | IP SANs (e.g. Proxmox `:8006`) | 1y |
| `pki_int_servers` | `server-dns` | DNS SANs for cert-manager / Traefik | 90d |
| `pki_int_clients` | `client-device` | Device CN, presence-only mTLS | 1y |
| `pki_int_clients` | `client-user` | SAN email / username | 90d |

Intermediate TTLs ≤ root. Server/client intermediate validity ~5y each (renew before expiry; document re-sign).

**Bootstrap (once, root token / break-glass — extend `bootstrap-notes.yaml`):**

1. Enable `pki_root`, tune max lease, generate root (`common_name` e.g. `Dominik Siejak Homelab Root CA`, `ttl=87600h`).
2. Export root CA PEM → 1Password item (Servers/openbao or dedicated PKI item) + local trust install runbook.
3. Enable `pki_int_servers` / `pki_int_clients`, generate intermediate CSRs, sign with root, set signed certs, configure URLs (`issuing_certificates`, `crl_distribution_points`) to `https://openbao.dominiksiejak.pl/v1/<mount>/ca` and `.../crl`.
4. Hand off: tofu owns roles, ACLs, kubernetes role for cert-manager, AppRole/OIDC policy updates.

Tofu **must not** create `vault_pki_secret_backend_root_cert` for this root (state leak). Tofu **may** manage mounts if import-friendly; prefer mounts created in bootstrap and imported, or manage ints/roles only if mounts already exist.

### 2. Policies and auth

- New policy `pki-cert-manager`: sign/issue on `pki_int_servers/sign/server-dns` and `pki_int_servers/issue/server-dns` (read CA/CRL as needed).
- New kubernetes auth role `cert-manager` bound to SA `cert-manager` (or dedicated SA) in `cert-manager` namespace → `pki-cert-manager`.
- Policy `pki-operator` (OIDC admin / break-glass): issue client + server roles, revoke, tidy.
- Existing `eso-read` unchanged (KV only). Do not grant ESO leaf issue.

### 3. cert-manager

- `ClusterIssuer` `openbao-servers` using Vault issuer → OpenBao Kubernetes auth → role `cert-manager` → path `pki_int_servers` / role `server-dns`.
- Pilot `Certificate` for `auth.dominiksiejak.pl` → Secret e.g. `auth-openbao-tls` in `authentik` (or `traefik`) namespace.
- **Do not** point live Authentik IngressRoute at that Secret in pilot until devices trust the root; verify `Certificate` Ready + chain only. LE / empty `tls: {}` stays default.
- Keep `ClusterIssuer` `letsencrypt` as-is.

### 4. Traefik mTLS (pilot)

- ConfigMap/Secret with **client intermediate CA** (or root) PEM for client verification.
- `TLSOption` e.g. `mtls-strict`: `clientAuth.clientAuthType: RequireAndVerifyClientCert`, `secretNames` → CA secret.
- Pilot host: dedicated `mtls-demo.dominiksiejak.pl` (AdGuard rewrite + IngressRoute → trivial backend or whoami), **not** `auth.dominiksiejak.pl` (would break public OIDC) and not blanket `proxmox.dominiksiejak.pl` until enroll done.
- Later: optional `VerifyClientCertIfGiven` on selected LAN routes; out of pilot.

### 5. Cloudflare Access mTLS (pilot)

- Upload client-int (or root) via `cloudflare_zero_trust_access_mtls_certificate` in `tofu/cloudflare`.
- One Access application (prefer a host already behind country allowlist pain, e.g. a non-exception host — **not** auth OIDC callbacks): add policy that allows when client certificate is presented (associated_hostnames / cert rule per CF provider schema).
- Country ruleset stays; mTLS policy is alternate allow path for that Access app.
- Tunnel origin unchanged (no origin-pull mTLS).

### 6. Proxmox / IP server cert (pilot)

- Issue via `bao write pki_int_servers/issue/server-ip` with IP SAN matching the live Proxmox management IP in [`lan-proxmox` EndpointSlice](../../../kubernetes/networking/traefik/resources/backends/lan-proxmox.yaml) (**192.168.89.254** today; user example `.253` is fine for other IP boxes later).
- Install leaf + chain on Proxmox TLS settings; browsers with root installed → no warning on `https://192.168.89.254:8006`.
- Traefik `proxmox.dominiksiejak.pl` may keep LE at edge and `serversTransport` insecure to backend, or later trust OpenBao for backend verify — backend trust tightening is **out of pilot**.

## Pilot acceptance

1. Root PEM installs on one macOS/iOS/Android/Linux test device; browser trusts Proxmox IP cert.
2. `Certificate`/`ClusterIssuer` Ready for `auth-openbao-tls` without flipping Authentik IngressRoute.
3. `curl --cert --key https://mtls-demo.dominiksiejak.pl` succeeds; without client cert → 4xx/TLS fail.
4. Cloudflare: device with client cert reaches pilot Access app from a non-allowlisted country path (or CF’s mTLS test); without cert → existing deny/challenge.
5. Root private key never appears in git or `tofu/openbao` state; only CA PEMs and runbook.

## Ops / failure modes

| Failure | Handling |
| --- | --- |
| OpenBao sealed | Unseal CronJob / existing runbook; no leaf issue until unsealed |
| Intermediate expiry | Re-CSR, sign with root, tofu refresh; renew leaves |
| Lost client cert | Revoke serial via OpenBao; CRL/OCSP URLs configured; CF/Traefik pick up per cache |
| Wrong CA on Cloudflare | Re-upload client-int; Access fails closed for mTLS policy |
| Accidental auth cutover to OpenBao TLS | Revert IngressRoute `tls.secretName`; LE default returns |

## Threat notes (short)

- Anyone with root PEM can **trust** forged servers only if attacker also has a **server-int** private key — protect int + OpenBao ACL.
- Client-int compromise → attacker can mint mTLS clients → revoke int, rotate CF CA + Traefik CA, re-enroll devices.
- Do not put client issue on ESO or world-readable policies.

## File touch map (planning hint)

| Area | Paths |
| --- | --- |
| OpenBao tofu | `tofu/openbao/pki*.tf`, `policies.tf`, `auth_kubernetes.tf` |
| Bootstrap | `kubernetes/platform/openbao/resources/bootstrap-notes.yaml` |
| cert-manager | `kubernetes/platform/cert-manager/resources/` (issuer + pilot Certificate) |
| Traefik | `kubernetes/networking/traefik/resources/` (TLSOption, CA secret/ESO, mtls-demo route) |
| DNS | `tofu/adguard` rewrite for `mtls-demo` if needed |
| Cloudflare | `tofu/cloudflare` mTLS CA + one Access app policy |
| Auth class | `scripts/auth_classification.yaml` entry for `mtls-demo` |

## Open follow-ups (explicitly later)

- Flip Authentik (or other) IngressRoutes to OpenBao secondary TLS.
- Auto-login / header mapping from `client-user` SAN into Authentik or apps.
- Broad Cloudflare Access mTLS + Traefik attachment list.
- Backend `ServersTransport` verify against OpenBao for Proxmox/NAS.
