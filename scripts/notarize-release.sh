#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="RightClickFocus"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/packaging/Info.plist")}"
NOTARY_PROFILE="${NOTARY_PROFILE:-RightClickFocus-notary}"
ZIP_PATH="$ROOT/build/$APP_NAME-$VERSION.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"

"$ROOT/scripts/package-release.sh" "$VERSION"

echo "Submitting $ZIP_PATH to Apple notary service with profile $NOTARY_PROFILE"
xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "Stapling notarization ticket"
xcrun stapler staple "$ROOT/build/$APP_NAME.app"
xcrun stapler validate "$ROOT/build/$APP_NAME.app"

rm -f "$ZIP_PATH" "$CHECKSUM_PATH"
ditto -c -k --keepParent "$ROOT/build/$APP_NAME.app" "$ZIP_PATH"

(
  cd "$ROOT/build"
  shasum -a 256 "$(basename "$ZIP_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

spctl --assess --type execute --verbose=4 "$ROOT/build/$APP_NAME.app"

echo "Notarized release ready:"
echo "$ZIP_PATH"
echo "$CHECKSUM_PATH"
