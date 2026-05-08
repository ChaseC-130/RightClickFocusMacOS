#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="RightClickFocus"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/packaging/Info.plist")}"
NOTARY_PROFILE="${NOTARY_PROFILE:-RightClickFocus-notary}"
ZIP_PATH="$ROOT/build/$APP_NAME-$VERSION.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"
DMG_PATH="$ROOT/build/$APP_NAME-$VERSION.dmg"
DMG_CHECKSUM_PATH="$DMG_PATH.sha256"

RIGHTCLICKFOCUS_OFFICIAL_RELEASE=1 "$ROOT/scripts/build-app.sh"

rm -f "$ZIP_PATH" "$CHECKSUM_PATH" "$DMG_PATH" "$DMG_CHECKSUM_PATH"
ditto -c -k --keepParent "$ROOT/build/$APP_NAME.app" "$ZIP_PATH"

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

"$ROOT/scripts/package-dmg.sh" "$VERSION" --no-build

DMG_SIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
if [[ -z "$DMG_SIGN_IDENTITY" ]]; then
  DMG_SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk '/Developer ID Application/ { print $2; exit }')"
fi

if [[ -z "$DMG_SIGN_IDENTITY" ]]; then
  echo "Could not find a Developer ID Application identity for signing the DMG." >&2
  exit 1
fi

echo "Signing DMG with $DMG_SIGN_IDENTITY"
codesign --force --timestamp --sign "$DMG_SIGN_IDENTITY" "$DMG_PATH"

echo "Submitting $DMG_PATH to Apple notary service with profile $NOTARY_PROFILE"
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "Stapling notarization ticket to DMG"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

(
  cd "$ROOT/build"
  shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$DMG_CHECKSUM_PATH")"
)

spctl --assess --type execute --verbose=4 "$ROOT/build/$APP_NAME.app"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"

echo "Notarized release ready:"
echo "$ZIP_PATH"
echo "$CHECKSUM_PATH"
echo "$DMG_PATH"
echo "$DMG_CHECKSUM_PATH"
