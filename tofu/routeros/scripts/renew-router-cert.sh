#!/usr/bin/env bash
# Renew the RouterOS TLS certificate (www-ssl :443 + api-ssl :8729).
#
# Issues a fresh leaf from OpenBao pki_int_servers/server-ip (IP SAN 192.168.89.1),
# imports it on the router, points both services at it, then removes older
# router-* certificates. The private key only lives in a 0700 temp dir that is
# wiped on exit; it is never printed.
#
# The certificate TTL is 1y (role max_ttl). Run this before it expires:
#   ssh router '/certificate print where name~"router-"'   # check invalid-after
#
# Usage:
#   tofu/routeros/scripts/renew-router-cert.sh            # issue + install
#   tofu/routeros/scripts/renew-router-cert.sh --dry-run  # issue + verify only
#
# Needs: vault, jq, openssl, ssh/scp access as `router`, AppRole files in
# ~/.config/openbao/{role_id,secret_id}.
set -euo pipefail

ROUTER="${ROUTER:-router}"
ROUTER_IP="${ROUTER_IP:-192.168.89.1}"
export VAULT_ADDR="${VAULT_ADDR:-https://bao.dominiksiejak.pl}"
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

for bin in vault jq openssl ssh scp; do
  command -v "$bin" >/dev/null || { echo "missing: $bin" >&2; exit 1; }
done

work="$(mktemp -d)"
chmod 700 "$work"
trap 'rm -rf "$work"' EXIT

stamp="$(date +%Y%m%d)"
name="router-${stamp}"

VAULT_TOKEN="$(vault write -field=token auth/approle/login \
  role_id="$(cat ~/.config/openbao/role_id)" \
  secret_id="$(cat ~/.config/openbao/secret_id)")"
export VAULT_TOKEN

vault write -format=json pki_int_servers/issue/server-ip \
  common_name=router-lan ip_sans="$ROUTER_IP" ttl=8760h >"$work/issue.json"

jq -r .data.certificate "$work/issue.json" >"$work/$name.crt"
jq -r .data.private_key "$work/issue.json" >"$work/$name.key"
chmod 600 "$work/$name.key"

# Sanity: IP SAN present, key matches, not already expired.
openssl x509 -in "$work/$name.crt" -noout -ext subjectAltName | grep -q "$ROUTER_IP" \
  || { echo "issued cert lacks IP SAN $ROUTER_IP" >&2; exit 1; }
[[ "$(openssl x509 -in "$work/$name.crt" -noout -pubkey | openssl sha256)" == \
   "$(openssl pkey -in "$work/$name.key" -pubout | openssl sha256)" ]] \
  || { echo "cert/key mismatch" >&2; exit 1; }
openssl x509 -in "$work/$name.crt" -noout -enddate

if ((DRY_RUN)); then
  echo "dry run: certificate issued and verified, nothing installed"
  exit 0
fi

scp -q "$work/$name.crt" "$work/$name.key" "$ROUTER:/"
ssh -o BatchMode=yes "$ROUTER" <<EOF
/certificate import file-name=$name.crt passphrase=""
/certificate import file-name=$name.key passphrase=""
/file remove [find where name="$name.crt"]
/file remove [find where name="$name.key"]
/ip service set [find where name="www-ssl"] certificate=$name.crt_0
/ip service set [find where name="api-ssl"] certificate=$name.crt_0
/certificate remove [find where name~"^router" and name!="$name.crt_0"]
/certificate print where name~"^router"
EOF

curl -sS --max-time 8 -o /dev/null -k -w "https $ROUTER_IP -> HTTP %{http_code}\n" "https://$ROUTER_IP/"
echo "done: $name installed on www-ssl and api-ssl"
