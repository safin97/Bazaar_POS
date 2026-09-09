#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
release_id="$(python3 -c 'from datetime import datetime, timezone; print(datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S%f"))')"
flutter build web --no-web-resources-cdn --dart-define="APP_BUILD_ID=$release_id"
python3 - "$release_id" <<'PY'
import json, sys
from pathlib import Path
Path('build/web/app-update.json').write_text(json.dumps({'buildId': sys.argv[1]}))
PY
