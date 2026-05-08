#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="RightClickFocus"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/packaging/Info.plist")}"
SKIP_BUILD="${2:-}"
ARTIFACT_BASENAME="$APP_NAME-$VERSION"
APP_PATH="$ROOT/build/$APP_NAME.app"
DMG_PATH="$ROOT/build/$ARTIFACT_BASENAME.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"
TMP_DMG="$ROOT/build/$ARTIFACT_BASENAME-rw.dmg"
DS_STORE_TEMPLATE="$ROOT/packaging/dmg/DS_Store"
MOUNT_DIR=""
DEVICE=""
VOLUME_NAME="$APP_NAME"

if [[ "$SKIP_BUILD" != "--no-build" ]]; then
  "$ROOT/scripts/build-app.sh"
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle at $APP_PATH" >&2
  exit 1
fi

cleanup() {
  if [[ -n "$DEVICE" ]]; then
    hdiutil detach "$DEVICE" -quiet || true
  fi

  if [[ -n "$MOUNT_DIR" ]]; then
    rm -rf "$MOUNT_DIR"
  fi

  rm -f "$TMP_DMG"
}
trap cleanup EXIT

rm -f "$DMG_PATH" "$CHECKSUM_PATH" "$TMP_DMG"
MOUNT_DIR="$(mktemp -d "$ROOT/build/dmg-mount.XXXXXX")"

hdiutil create \
  -size 64m \
  -fs HFS+ \
  -volname "$VOLUME_NAME" \
  -ov \
  "$TMP_DMG" >/dev/null

ATTACH_OUTPUT="$(hdiutil attach "$TMP_DMG" -readwrite -noverify -noautoopen -mountpoint "$MOUNT_DIR")"
DEVICE="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/Apple_HFS/ { print $1; exit }')"

if [[ -z "$DEVICE" ]]; then
  echo "Could not determine mounted DMG device." >&2
  exit 1
fi

if [[ -z "$MOUNT_DIR" || ! -d "$MOUNT_DIR" ]]; then
  echo "Could not determine mounted DMG path." >&2
  exit 1
fi

ditto "$APP_PATH" "$MOUNT_DIR/$APP_NAME.app"
ln -s /Applications "$MOUNT_DIR/Applications"

if [[ -f "$DS_STORE_TEMPLATE" && "${RIGHTCLICKFOCUS_REFRESH_DMG_LAYOUT:-}" != "1" ]]; then
  cp "$DS_STORE_TEMPLATE" "$MOUNT_DIR/.DS_Store"
else
  set +e
  osascript <<APPLESCRIPT
with timeout of 10 seconds
  tell application "Finder"
    tell disk "$VOLUME_NAME"
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set bounds of container window to {120, 120, 650, 420}
      set viewOptions to icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to 112
      set position of item "$APP_NAME.app" of container window to {165, 145}
      set position of item "Applications" of container window to {395, 145}
      update without registering applications
      delay 1
      close
    end tell
  end tell
end timeout
APPLESCRIPT
  APPLESCRIPT_STATUS=$?
  set -e

  if [[ "$APPLESCRIPT_STATUS" -ne 0 ]]; then
    echo "Warning: Finder window layout could not be customized. The DMG contents are still usable." >&2
  else
    cp "$MOUNT_DIR/.DS_Store" "$DS_STORE_TEMPLATE"
  fi
fi

sync
hdiutil detach "$DEVICE" -quiet
DEVICE=""

hdiutil convert "$TMP_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH" >/dev/null

(
  cd "$ROOT/build"
  shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

echo "Packaged $DMG_PATH"
echo "Wrote $CHECKSUM_PATH"
