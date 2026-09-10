#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
release_id="$(python3 -c 'from datetime import datetime, timezone; print(datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S%f"))')"
release_version="$(python3 -c 'import re; from pathlib import Path; print(re.search(r"^version:\s*(\S+)", Path("pubspec.yaml").read_text(), re.M)[1])')"
flutter build web --no-web-resources-cdn \
  --dart-define="APP_BUILD_ID=$release_id" \
  --dart-define="APP_VERSION=${release_version%%+*}" \
  --dart-define="APP_BUILD_NUMBER=${release_version##*+}" "$@"
python3 - "$release_id" "$release_version" <<'PY'
import json, sys
from pathlib import Path
version, _, build = sys.argv[2].partition('+')
Path('build/web/app-update.json').write_text(json.dumps({
    'buildId': sys.argv[1], 'version': version, 'buildNumber': build,
}))
PY
