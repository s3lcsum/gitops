#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.jellyfin.secrets" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/../.jellyfin.secrets"
  set +a
fi

JF_BASE="${JF_BASE:-https://jellyfin.dominiksiejak.pl}"
JF_API_KEY="${JF_API_KEY:?set JF_API_KEY in .jellyfin.secrets}"

jf_api() { # jf_api GET|POST /path [json]
  local method="$1" path="$2" data="${3:-}"
  if [ -n "$data" ]; then
    curl -fsS -X "$method" "$JF_BASE$path" \
      -H "X-Emby-Token: $JF_API_KEY" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" -d "$data"
  else
    curl -fsS -X "$method" "$JF_BASE$path" \
      -H "X-Emby-Token: $JF_API_KEY" \
      -H "Accept: application/json"
  fi
}

plugin_id() { # plugin_id NAME -> plugin GUID (the server reports Ids without dashes)
  jf_api GET "/Plugins" | python3 -c \
    "import sys,json; [print(p['Id']) for p in json.load(sys.stdin) if p['Name']=='$1']"
}
