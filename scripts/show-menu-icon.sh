#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT/build/RightClickFocus.app"
EXECUTABLE="$APP_PATH/Contents/MacOS/RightClickFocus"

if [[ ! -x "$EXECUTABLE" ]]; then
  "$ROOT/scripts/build-app.sh"
fi

"$EXECUTABLE" --show-menu-icon
echo "RightClickFocus menu bar icon enabled."
