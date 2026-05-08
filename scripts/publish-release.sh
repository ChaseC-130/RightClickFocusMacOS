#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="RightClickFocus"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/packaging/Info.plist")}"
TAG_NAME="v${VERSION#v}"
ZIP_PATH="$ROOT/build/$APP_NAME-$VERSION.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"
DMG_PATH="$ROOT/build/$APP_NAME-$VERSION.dmg"
DMG_CHECKSUM_PATH="$DMG_PATH.sha256"

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI is required to publish releases: https://cli.github.com/" >&2
  exit 1
fi

if [[ ! -f "$ZIP_PATH" || ! -f "$CHECKSUM_PATH" || ! -f "$DMG_PATH" || ! -f "$DMG_CHECKSUM_PATH" ]]; then
  echo "Missing release artifacts. Run scripts/notarize-release.sh $VERSION first." >&2
  exit 1
fi

gh auth status >/dev/null

if ! git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
  git tag "$TAG_NAME"
fi

git push origin main
git push origin "$TAG_NAME"

cat > "$ROOT/build/release-notes.md" <<'NOTES'
Download the DMG, open it, drag `RightClickFocus.app` to Applications, then open it from Applications.

On first launch, grant Accessibility and Input Monitoring permissions in System Settings.
NOTES

if gh release view "$TAG_NAME" >/dev/null 2>&1; then
  gh release upload "$TAG_NAME" "$DMG_PATH" "$DMG_CHECKSUM_PATH" "$ZIP_PATH" "$CHECKSUM_PATH" --clobber
else
  gh release create "$TAG_NAME" "$DMG_PATH" "$DMG_CHECKSUM_PATH" "$ZIP_PATH" "$CHECKSUM_PATH" \
    --title "RightClickFocus $TAG_NAME" \
    --notes-file "$ROOT/build/release-notes.md"
fi
