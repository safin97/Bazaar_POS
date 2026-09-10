#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash tool/build_web.sh "$@"
echo "Open Bazaar POS at http://localhost:8080 (keep this terminal open)."
exec python3 -m http.server 8080 --bind 127.0.0.1 --directory build/web
