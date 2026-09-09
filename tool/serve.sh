#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
bash tool/build_web.sh
exec python3 -m http.server 8080 --bind 127.0.0.1 --directory build/web
