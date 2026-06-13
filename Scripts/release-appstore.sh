#!/usr/bin/env bash
# Build + export a Mac App Store package for Tray.
# Requires: full Xcode, xcodegen, an Apple Developer Program membership, and a
# signed-in account (Apple Distribution + Mac Installer Distribution certs).
#
#   export DEVELOPMENT_TEAM=ABCDE12345          # required (10-char Team ID)
#   export BUNDLE_ID=com.plainware.tray         # optional (must match GoogleService-Info if Firebase is on)
#   Scripts/release-appstore.sh
#
# Output: build/Tray.pkg  → upload with fastlane (Scripts: `fastlane mac upload`)
#         or Transporter / `xcrun altool --upload-app -f build/Tray.pkg -t macos ...`
set -euo pipefail
cd "$(dirname "$0")/.."

: "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to your 10-char Apple Team ID}"
BUNDLE_ID="${BUNDLE_ID:-com.plainware.tray}"
SCHEME="Tray"

command -v xcodebuild >/dev/null || { echo "❌ full Xcode required (xcodebuild not found)"; exit 1; }
command -v xcodegen   >/dev/null || { echo "❌ xcodegen required: brew install xcodegen"; exit 1; }

echo "==> Generating Xcode project (team $DEVELOPMENT_TEAM)"
DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" xcodegen generate

echo "==> Archiving"
rm -rf build/Tray.xcarchive build/export
xcodebuild -project Tray.xcodeproj -scheme "$SCHEME" -configuration Release \
  -archivePath build/Tray.xcarchive archive \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"

echo "==> Exporting for App Store"
xcodebuild -exportArchive -archivePath build/Tray.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions-appstore.plist

PKG=$(ls build/export/*.pkg 2>/dev/null | head -1 || true)
[ -n "$PKG" ] && cp "$PKG" build/Tray.pkg && echo "✅ build/Tray.pkg ready" || echo "⚠️  no .pkg produced — check signing"
echo "Next: upload with  fastlane mac upload   (or Transporter)."
