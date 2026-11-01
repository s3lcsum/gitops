#!/usr/bin/env bash
# One-shot: push each module's defaults.auto.tfvars to
# secret/<module> field tfvars (raw HCL), mount secret.
# Expects VAULT_ADDR + VAULT_TOKEN already set (AppRole or token login).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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

modules=(
  adguard authentik backblaze cloudflare gcp grafana
  netbox openbao proxmox routeros unifi
)

uploaded=0
skipped=0
for m in "${modules[@]}"; do
  src="${ROOT}/${m}/defaults.auto.tfvars"
  if [[ ! -f "${src}" ]]; then
    echo "skip ${m}: no defaults.auto.tfvars"
    skipped=$((skipped + 1))
    continue
  fi
  echo "put secret/${m} (tfvars from ${src})"
  "${CLI[@]}" kv put -mount=secret "${m}" "tfvars=@${src}"
  uploaded=$((uploaded + 1))
done

echo "done: uploaded=${uploaded} skipped=${skipped}"
