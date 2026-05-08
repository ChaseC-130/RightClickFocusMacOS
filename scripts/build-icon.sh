#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONSET_DIR="$ROOT/build/AppIcon.iconset"
ICNS_PATH="$ROOT/build/AppIcon.icns"

mkdir -p "$ROOT/build"

swift "$ROOT/scripts/generate-app-icon.swift" "$ICONSET_DIR"
rm -f "$ICNS_PATH"
iconutil -c icns -o "$ICNS_PATH" "$ICONSET_DIR"

echo "Generated $ICNS_PATH"
