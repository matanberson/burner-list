#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  if command -v security >/dev/null 2>&1; then
    CLOUDFLARE_API_TOKEN="$(security find-generic-password -a "$USER" -s burner-list-cloudflare-api-token -w 2>/dev/null || true)"
    export CLOUDFLARE_API_TOKEN
  fi
fi

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  cat >&2 <<'EOF'
Missing CLOUDFLARE_API_TOKEN.

Store it once in macOS Keychain:
  security add-generic-password -a "$USER" -s burner-list-cloudflare-api-token -w "PASTE_TOKEN_HERE" -U

Or set it just for this shell:
  export CLOUDFLARE_API_TOKEN="PASTE_TOKEN_HERE"

Then run:
  ./scripts/deploy.sh
EOF
  exit 1
fi

npx wrangler deploy
