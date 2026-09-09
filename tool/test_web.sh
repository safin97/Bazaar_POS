#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Flutter's browser test server serves fixtures relative to test/.
# Stage the same SQLite runtime as the app; never use the user's browser profile.
fixture='test/browser/sqlite3.wasm'
cp web/sqlite3.wasm "$fixture"
trap 'rm -f "$fixture"' EXIT
flutter test --platform chrome test/browser "$@"
