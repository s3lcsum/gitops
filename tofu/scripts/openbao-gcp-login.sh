#!/usr/bin/env bash
# Exchange a Google ID token for an OpenBao token.
# The token is the github-actions-tofu service account, audience vault/<role>,
# with the email claim. OpenBao role: auth/jwt/role/cicd-terraform.
# Writes ~/.config/openbao/token.env (mode 600). In GitHub Actions, also
# appends VAULT_TOKEN to GITHUB_ENV. Never prints the token.

set -euo pipefail

ROLE="${OPENBAO_GCP_ROLE:-cicd-terraform}"
AUDIENCE="${OPENBAO_GCP_AUDIENCE:-vault/${ROLE}}"
SA="${OPENBAO_GCP_SERVICE_ACCOUNT:-github-actions-tofu@dominiksiejak.iam.gserviceaccount.com}"
ADDR="${VAULT_ADDR:-https://bao.dominiksiejak.pl}"
MOUNT="${OPENBAO_JWT_PATH:-jwt}"

redact() {
  sed -E 's/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/<redacted-jwt>/g; s/s\.[A-Za-z0-9]{8,}/<redacted-token>/g'
}

id_token="${GCP_ID_TOKEN:-}"

if [ -z "$id_token" ] && [ -n "${GCP_ACCESS_TOKEN:-}" ]; then
  gen="$(curl -sS -m 30 \
    -H "Authorization: Bearer ${GCP_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"audience\":\"${AUDIENCE}\",\"includeEmail\":true}" \
    "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${SA}:generateIdToken" || true)"
  id_token="$(printf '%s' "$gen" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
  if [ -z "$id_token" ]; then
    echo "openbao-gcp-login: generateIdToken failed for ${SA}" >&2
    printf '%s\n' "$gen" | redact >&2
  fi
fi

if [ -z "$id_token" ] && command -v gcloud >/dev/null 2>&1; then
  id_token="$(gcloud auth print-identity-token --audiences="$AUDIENCE" 2>/dev/null || true)"
  if [ -z "$id_token" ]; then
    id_token="$(gcloud auth print-identity-token --audiences="$AUDIENCE" --impersonate-service-account="$SA" 2>/dev/null || true)"
  fi
fi

if [ -z "$id_token" ]; then
  echo "openbao-gcp-login: no Google ID token for ${SA} (audience ${AUDIENCE})" >&2
  exit 2
fi

payload="$(printf '{"role":"%s","jwt":"%s"}' "$ROLE" "$id_token")"
unset id_token

tmp="$(mktemp)"
code="$(curl -sS -m 30 -o "$tmp" -w '%{http_code}' \
  -H "Content-Type: application/json" \
  -d "$payload" \
  "${ADDR}/v1/auth/${MOUNT}/login" || true)"
unset payload

body="$(cat "$tmp")"
rm -f "$tmp"
client_token="$(printf '%s' "$body" | sed -n 's/.*"client_token":"\([^"]*\)".*/\1/p')"

if [ -z "$client_token" ]; then
  echo "openbao-gcp-login: auth/${MOUNT} login failed http=${code}" >&2
  printf '%s\n' "$body" | redact >&2
  exit 1
fi
unset body

umask 077
mkdir -p "${HOME}/.config/openbao"
printf 'VAULT_TOKEN=%s\n' "$client_token" > "${HOME}/.config/openbao/token.env"
chmod 600 "${HOME}/.config/openbao/token.env"

if [ -n "${GITHUB_ENV:-}" ]; then
  echo "::add-mask::${client_token}"
  printf 'VAULT_TOKEN=%s\n' "$client_token" >> "$GITHUB_ENV"
fi
unset client_token

echo "openbao-gcp-login: ${SA} -> auth/${MOUNT} role ${ROLE}"
