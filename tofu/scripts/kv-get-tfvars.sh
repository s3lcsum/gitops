#!/usr/bin/env bash
# Print secret/terraform_env/<module> field tfvars to stdout.
# Prefers bao; falls back to vault (OpenBao = Vault API).
set -euo pipefail
module="${1:?module name}"
: "${VAULT_ADDR:?}"
: "${VAULT_TOKEN:?}"

if command -v bao >/dev/null 2>&1; then
  CLI=(bao)
elif command -v vault >/dev/null 2>&1; then
  CLI=(vault)
else
  echo "need bao or vault CLI on PATH" >&2
  exit 1
fi

if ! "${CLI[@]}" kv get -field=tfvars -mount=secret "terraform_env/${module}"; then
  echo "missing secret/terraform_env/${module} (field tfvars). Upload: make -C tofu tg-upload" >&2
  exit 1
fi
