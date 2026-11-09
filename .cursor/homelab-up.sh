#!/usr/bin/env bash
# Per-boot homelab access for Cursor cloud agents.
# WireGuard first, then pin bao/argocd to the LAN Traefik address, then
# write kubeconfig, Argo CD context, and an OpenBao token when the
# Cursor environment secrets are present. Secrets are never printed.
#
# Required Cursor environment secrets:
#   WIREGUARD_PRIVATE_KEY, WIREGUARD_PUBLIC_KEY
#   OPENBAO_APPROLE_ROLE_ID, OPENBAO_APPROLE_SECRET_ID
#   ARGOCD_AUTH_TOKEN
#   KUBECONFIG_B64   (base64 of a kubeconfig whose server is https://192.168.89.252:6443)
# Optional:
#   GOOGLE_CREDENTIALS_JSON  (service-account JSON for the GCS state bucket)
#   KUBECONFIG_YAML          (used when KUBECONFIG_B64 is unset)
#   GCP_ID_TOKEN             (skips AppRole when a Google ID token is already available)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LAN_TRAEFIK="192.168.89.252"
HOSTS_BEGIN="# BEGIN cursor-homelab"
HOSTS_END="# END cursor-homelab"

if [ "$(uname -s)" != "Linux" ]; then
  echo "homelab-up: skip (linux only)"
  exit 0
fi

bash "$SCRIPT_DIR/wireguard-up.sh"

if ! ip link show wg0 >/dev/null 2>&1; then
  echo "homelab-up: wg0 is down; LAN CLIs not configured"
  exit 0
fi

ready=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  if sudo wg show wg0 latest-handshakes 2>/dev/null | awk '$2 ~ /^[1-9]/ { found=1 } END { exit !found }'; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  echo "homelab-up: WireGuard has no handshake yet" >&2
  exit 1
fi

# Public DNS for these names is the WAN address, which this peer cannot use.
# Pin them at the LAN Traefik IP so bao and argocd hit the cluster.
sudo python3 - "$LAN_TRAEFIK" "$HOSTS_BEGIN" "$HOSTS_END" <<'PY'
import pathlib, sys
ip, begin, end = sys.argv[1:]
path = pathlib.Path("/etc/hosts")
text = path.read_text() if path.exists() else ""
block = f"{begin}\n{ip} bao.dominiksiejak.pl argocd.dominiksiejak.pl\n{end}\n"
if begin in text and end in text:
    pre, rest = text.split(begin, 1)
    _, post = rest.split(end, 1)
    post = post.lstrip("\n")
    text = pre + block + post
else:
    if text and not text.endswith("\n"):
        text += "\n"
    text += block
path.write_text(text)
PY
echo "homelab-up: pinned bao.dominiksiejak.pl and argocd.dominiksiejak.pl to ${LAN_TRAEFIK}"

missing=()

umask 077
mkdir -p "${HOME}/.kube" "${HOME}/.config/argocd" "${HOME}/.config/openbao" "${HOME}/.config/gcloud"

if [ -n "${KUBECONFIG_B64:-}" ]; then
  if ! printf '%s' "$KUBECONFIG_B64" | base64 -d > "${HOME}/.kube/config" 2>/dev/null; then
    echo "homelab-up: KUBECONFIG_B64 is not valid base64" >&2
    rm -f "${HOME}/.kube/config"
    exit 1
  fi
  chmod 600 "${HOME}/.kube/config"
  echo "homelab-up: wrote ~/.kube/config from KUBECONFIG_B64"
elif [ -n "${KUBECONFIG_YAML:-}" ]; then
  printf '%s\n' "$KUBECONFIG_YAML" > "${HOME}/.kube/config"
  chmod 600 "${HOME}/.kube/config"
  echo "homelab-up: wrote ~/.kube/config from KUBECONFIG_YAML"
else
  missing+=("KUBECONFIG_B64")
fi

if [ -n "${ARGOCD_AUTH_TOKEN:-}" ]; then
  token="$(printf '%s' "$ARGOCD_AUTH_TOKEN" | tr -d '[:space:]')"
  umask 077
  cat > "${HOME}/.config/argocd/config" <<EOF
contexts:
- name: homelab
  server: argocd.dominiksiejak.pl
  user: homelab
current-context: homelab
servers:
- grpc-web: true
  server: argocd.dominiksiejak.pl
users:
- auth-token: ${token}
  name: homelab
EOF
  chmod 600 "${HOME}/.config/argocd/config"
  unset token
  echo "homelab-up: wrote Argo CD context argocd.dominiksiejak.pl (grpc-web)"
else
  missing+=("ARGOCD_AUTH_TOKEN")
fi

if [ -n "${GOOGLE_CREDENTIALS_JSON:-}" ]; then
  printf '%s\n' "$GOOGLE_CREDENTIALS_JSON" > "${HOME}/.config/gcloud/application_default_credentials.json"
  chmod 600 "${HOME}/.config/gcloud/application_default_credentials.json"
  echo "homelab-up: wrote Google application-default credentials"
fi

export VAULT_ADDR="https://bao.dominiksiejak.pl"
export BAO_ADDR="$VAULT_ADDR"

gcp_status=0
"$REPO_ROOT/tofu/scripts/openbao-gcp-login.sh" || gcp_status="$?"
if [ "$gcp_status" -eq 0 ]; then
  echo "homelab-up: OpenBao login via Google ID token"
elif [ "$gcp_status" -ne 2 ]; then
  echo "homelab-up: Google ID token login failed; trying AppRole" >&2
fi

if [ "$gcp_status" -ne 0 ]; then
  if [ -z "${OPENBAO_APPROLE_ROLE_ID:-}" ] || [ -z "${OPENBAO_APPROLE_SECRET_ID:-}" ]; then
    [ -n "${OPENBAO_APPROLE_ROLE_ID:-}" ] || missing+=("OPENBAO_APPROLE_ROLE_ID")
    [ -n "${OPENBAO_APPROLE_SECRET_ID:-}" ] || missing+=("OPENBAO_APPROLE_SECRET_ID")
  else
    printf '%s' "$OPENBAO_APPROLE_ROLE_ID" > "${HOME}/.config/openbao/role_id"
    printf '%s' "$OPENBAO_APPROLE_SECRET_ID" > "${HOME}/.config/openbao/secret_id"
    chmod 600 "${HOME}/.config/openbao/role_id" "${HOME}/.config/openbao/secret_id"
    payload="$(jq -n --arg role_id "$OPENBAO_APPROLE_ROLE_ID" --arg secret_id "$OPENBAO_APPROLE_SECRET_ID" '{role_id:$role_id,secret_id:$secret_id}')"
    tmp="$(mktemp)"
    code="$(curl -sS -m 30 -o "$tmp" -w '%{http_code}' \
      -H "Content-Type: application/json" \
      --data-binary "$payload" \
      "${VAULT_ADDR}/v1/auth/approle/login" || true)"
    unset payload
    client_token="$(jq -r '.auth.client_token // empty' "$tmp" 2>/dev/null || true)"
    rm -f "$tmp"
    if [ -z "$client_token" ]; then
      echo "homelab-up: AppRole login failed http=${code}" >&2
      unset client_token
      exit 1
    fi
    printf 'VAULT_TOKEN=%s\n' "$client_token" > "${HOME}/.config/openbao/token.env"
    chmod 600 "${HOME}/.config/openbao/token.env"
    unset client_token
    echo "homelab-up: OpenBao login via AppRole"
  fi
fi

if [ "${#missing[@]}" -gt 0 ]; then
  echo "homelab-up: set these Cursor environment secrets: ${missing[*]}"
fi

if [ -f "${HOME}/.kube/config" ] && command -v kubectl >/dev/null 2>&1; then
  if kubectl --request-timeout=10s get ns >/dev/null; then
    echo "homelab-up: kubectl ready"
  else
    echo "homelab-up: kubectl could not list namespaces" >&2
    exit 1
  fi
fi

if [ -f "${HOME}/.config/argocd/config" ] && command -v argocd >/dev/null 2>&1; then
  if argocd account get-user-info >/dev/null; then
    echo "homelab-up: argocd ready"
  else
    echo "homelab-up: argocd account get-user-info failed" >&2
    exit 1
  fi
fi

if [ -f "${HOME}/.config/openbao/token.env" ] && command -v bao >/dev/null 2>&1; then
  if bao token lookup >/dev/null; then
    echo "homelab-up: bao ready"
  else
    echo "homelab-up: bao token lookup failed" >&2
    exit 1
  fi
fi

echo "homelab-up: done"
