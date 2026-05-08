#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="RightClickFocus"
APP_DIR="$ROOT/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

swift build --package-path "$ROOT" -c release

BIN_PATH="$(swift build --package-path "$ROOT" -c release --show-bin-path)/$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
"$ROOT/scripts/build-icon.sh"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
cp "$ROOT/packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT/build/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
chmod +x "$MACOS_DIR/$APP_NAME"

SIGN_IDENTITY="${CODESIGN_IDENTITY:-}"

if [[ -z "$SIGN_IDENTITY" && "${RIGHTCLICKFOCUS_OFFICIAL_RELEASE:-}" == "1" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk '/Developer ID Application/ { print $2; exit }')"
fi

if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "Signing with $SIGN_IDENTITY"
  if [[ "${RIGHTCLICKFOCUS_OFFICIAL_RELEASE:-}" == "1" || "$SIGN_IDENTITY" == Developer\ ID\ Application:* ]]; then
    codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
  else
    codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
  fi
else
  echo "Signing ad-hoc. Set CODESIGN_IDENTITY or RIGHTCLICKFOCUS_OFFICIAL_RELEASE=1 for certificate signing."
  codesign --force --deep --sign - "$APP_DIR"
fi

echo "Built $APP_DIR"
