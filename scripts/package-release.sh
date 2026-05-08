#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="RightClickFocus"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/packaging/Info.plist")}"
ARTIFACT_BASENAME="$APP_NAME-$VERSION"
ZIP_PATH="$ROOT/build/$ARTIFACT_BASENAME.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"

"$ROOT/scripts/build-app.sh"

rm -f "$ZIP_PATH" "$CHECKSUM_PATH"
ditto -c -k --keepParent "$ROOT/build/$APP_NAME.app" "$ZIP_PATH"

(
  cd "$ROOT/build"
  shasum -a 256 "$(basename "$ZIP_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

echo "Packaged $ZIP_PATH"
echo "Wrote $CHECKSUM_PATH"
