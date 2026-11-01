#!/usr/bin/env bash
# AppRole login against OpenBao (Vault-compatible API).
# Prefers `bao` CLI; falls back to `vault` (same HTTP API).
# Required env: VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID
# Prints export lines for: eval "$(make -C tofu tg-login)"
set -euo pipefail

: "${VAULT_ADDR:?set VAULT_ADDR (e.g. https://openbao.dominiksiejak.pl)}"
: "${VAULT_ROLE_ID:?set VAULT_ROLE_ID}"
: "${VAULT_SECRET_ID:?set VAULT_SECRET_ID}"

if command -v bao >/dev/null 2>&1; then
  CLI=(bao)
elif command -v vault >/dev/null 2>&1; then
  CLI=(vault)
else
  echo "need bao or vault CLI on PATH" >&2
  exit 1
fi

token="$("${CLI[@]}" write -field=token auth/approle/login \
  role_id="${VAULT_ROLE_ID}" \
  secret_id="${VAULT_SECRET_ID}")"

echo "export VAULT_ADDR=$(printf %q "${VAULT_ADDR}")"
echo "export VAULT_TOKEN=$(printf %q "${token}")"
