#!/bin/sh
# Homelab OpenBao CLI. The real binary is /usr/local/libexec/bao.
# Address is fixed. Token comes from the environment or the boot login file.
# Never print the token.
set -eu

export VAULT_ADDR="${VAULT_ADDR:-https://bao.dominiksiejak.pl}"
export BAO_ADDR="${BAO_ADDR:-$VAULT_ADDR}"

token_file="${HOME}/.config/openbao/token.env"
if [ -z "${VAULT_TOKEN:-}" ] && [ -f "$token_file" ]; then
  # shellcheck disable=SC1090
  . "$token_file"
  export VAULT_TOKEN
fi

exec /usr/local/libexec/bao "$@"
