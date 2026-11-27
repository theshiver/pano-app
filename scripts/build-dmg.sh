#!/usr/bin/env bash
set -euo pipefail

# Builds, Developer-ID signs, packages into a DMG, and optionally notarizes PanoDirect.
# Usage:
#   ./scripts/build-dmg.sh                 # local signed DMG (set SIGN_IDENTITY)
#   NOTARY_PROFILE=pano-notary ./scripts/build-dmg.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(awk -F'"' '/MARKETING_VERSION:/ {print $2; exit}' "$ROOT/project.yml")"
BUILD_DIR="$ROOT/.build/dmg"
ARCHIVE="$BUILD_DIR/PanoDirect.xcarchive"
DMG_ROOT="$BUILD_DIR/dmg-root"
OUT_DMG="$BUILD_DIR/Pano-$VERSION.dmg"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Can Cetin (S2RH54MMT3)}"

rm -rf "$BUILD_DIR"
mkdir -p "$DMG_ROOT"

xcodebuild archive \
  -project "$ROOT/Pano.xcodeproj" \
  -scheme PanoDirect \
  -configuration ReleaseDirect \
  -archivePath "$ARCHIVE" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime"

APP="$ARCHIVE/Products/Applications/Pano.app"
cp -R "$APP" "$DMG_ROOT/Pano.app"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create -volname "Pano" -srcfolder "$DMG_ROOT" -ov -format UDZO "$OUT_DMG"
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$OUT_DMG"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$OUT_DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$OUT_DMG"
fi

echo "DMG ready: $OUT_DMG"
shasum -a 256 "$OUT_DMG"
