#!/usr/bin/env bash
# Keep Cursor, OpenCode, and brand/ skill trees identical.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/brand}"
for dest in "$ROOT/.cursor/skills/brand" "$ROOT/.opencode/skills/brand"; do
  mkdir -p "$dest"
  rsync -a --delete \
    --exclude README.md \
    "$SRC/" "$dest/"
done
echo "Synced brand skill: brand/ -> .cursor/skills/brand/ and .opencode/skills/brand/"
