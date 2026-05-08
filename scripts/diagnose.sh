#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT/build/RightClickFocus.app"
EXECUTABLE="$APP_PATH/Contents/MacOS/RightClickFocus"
REPORT="$ROOT/build/right-click-focus-diagnostics.txt"

if [[ ! -x "$EXECUTABLE" ]]; then
  "$ROOT/scripts/build-app.sh"
fi

rm -f "$REPORT"
/usr/bin/open -W -n "$APP_PATH" --args --diagnose-to "$REPORT"

if [[ ! -f "$REPORT" ]]; then
  echo "No diagnostic report was written at $REPORT" >&2
  exit 1
fi

cat "$REPORT"
