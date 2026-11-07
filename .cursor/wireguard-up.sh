#!/usr/bin/env bash
# Bring up the cloud-agent WireGuard peer when this environment has keys.
# Peer cloud-agent is 192.168.200.11/32 on vpn.dominiksiejak.pl:51820.
# WIREGUARD_PRIVATE_KEY is that peer's private key.
# WIREGUARD_PUBLIC_KEY is the RouterOS server public key.
# Both are Cursor environment secrets. This script never writes them to git.
set -euo pipefail

if [ "$(uname -s)" != "Linux" ]; then
  echo "wireguard-up: skip (linux only)"
  exit 0
fi

priv="${WIREGUARD_PRIVATE_KEY:-}"
pub="${WIREGUARD_PUBLIC_KEY:-}"

if [ -z "$priv" ] || [ -z "$pub" ]; then
  echo "wireguard-up: WIREGUARD_PRIVATE_KEY and WIREGUARD_PUBLIC_KEY unset; tunnel not started"
  exit 0
fi

# 32-byte WireGuard keys, standard base64 with padding. Do not print the values.
key_ok() {
  [[ "$1" =~ ^[A-Za-z0-9+/]{43}=$ ]]
}
if ! key_ok "$priv" || ! key_ok "$pub"; then
  echo "wireguard-up: key material is present but not a WireGuard key; tunnel not started" >&2
  exit 1
fi

if ! command -v wg >/dev/null 2>&1 || ! command -v ip >/dev/null 2>&1; then
  echo "wireguard-up: wireguard tools are not installed" >&2
  exit 1
fi

address="192.168.200.11/32"
endpoint="vpn.dominiksiejak.pl:51820"

keyfile="$(mktemp)"
chmod 600 "$keyfile"
printf '%s\n' "$priv" > "$keyfile"
unset priv

cleanup() {
  if [ -n "${keyfile:-}" ] && [ -f "$keyfile" ]; then
    shred -u "$keyfile" 2>/dev/null || rm -f "$keyfile"
  fi
}
trap cleanup EXIT

if ip link show wg0 >/dev/null 2>&1; then
  sudo ip link delete dev wg0
fi

sudo ip link add dev wg0 type wireguard
sudo ip address add "$address" dev wg0
sudo wg set wg0 \
  private-key "$keyfile" \
  peer "$pub" \
  allowed-ips "192.168.89.0/24,192.168.200.0/24" \
  endpoint "$endpoint" \
  persistent-keepalive 25
unset pub
cleanup
trap - EXIT

sudo ip link set up dev wg0
sudo ip route replace 192.168.89.0/24 dev wg0
sudo ip route replace 192.168.200.0/24 dev wg0

if command -v resolvectl >/dev/null 2>&1; then
  sudo resolvectl dns wg0 192.168.89.252 || true
  sudo resolvectl domain wg0 '~dominiksiejak.pl' || true
fi

echo "wireguard-up: wg0 ${address} via ${endpoint}"
# transfer columns are rx/tx bytes. The first column is the peer public key; omit it.
sudo wg show wg0 transfer | awk '{print "transfer rx="$2" tx="$3}'
