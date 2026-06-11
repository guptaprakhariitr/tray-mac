#!/usr/bin/env bash
# bundle.sh — build a SwiftUI SPM executable into a runnable, ad-hoc-signed .app
# WITHOUT Xcode. Works on Command Line Tools only. For local dev/test loop.
#
# Usage:
#   Scripts/bundle.sh \
#     --package-dir Apps/Glaze \
#     --product Glaze \                 # SPM executable target name
#     --name Glaze \                    # display name (App.app)
#     --bundle-id com.plainware.glaze \
#     [--info-plist path/Info.plist] \  # optional; generated if omitted
#     [--entitlements path/App.entitlements] \
#     [--icon path/AppIcon.icns] \
#     [--config release|debug] \        # default: release
#     [--out dist] \                    # output dir; default: dist
#     [--open]                          # launch the app after building
set -euo pipefail

PKG_DIR=""; PRODUCT=""; NAME=""; BUNDLE_ID=""; INFO_PLIST=""; ENTITLEMENTS=""
ICON=""; CONFIG="release"; OUT="dist"; DO_OPEN=0
while [[ $# -gt 0 ]]; do case "$1" in
  --package-dir) PKG_DIR="$2"; shift 2;;
  --product) PRODUCT="$2"; shift 2;;
  --name) NAME="$2"; shift 2;;
  --bundle-id) BUNDLE_ID="$2"; shift 2;;
  --info-plist) INFO_PLIST="$2"; shift 2;;
  --entitlements) ENTITLEMENTS="$2"; shift 2;;
  --icon) ICON="$2"; shift 2;;
  --config) CONFIG="$2"; shift 2;;
  --out) OUT="$2"; shift 2;;
  --open) DO_OPEN=1; shift;;
  *) echo "unknown arg: $1" >&2; exit 2;;
esac; done

: "${PKG_DIR:?--package-dir required}"; : "${PRODUCT:?--product required}"
: "${NAME:?--name required}"; : "${BUNDLE_ID:?--bundle-id required}"

echo "==> swift build ($CONFIG) in $PKG_DIR"
( cd "$PKG_DIR" && swift build -c "$CONFIG" )
BIN="$PKG_DIR/.build/$CONFIG/$PRODUCT"
[[ -x "$BIN" ]] || { echo "binary not found: $BIN" >&2; exit 1; }

APP="$OUT/$NAME.app"; CONTENTS="$APP/Contents"
echo "==> assembling $APP"
rm -rf "$APP"; mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN" "$CONTENTS/MacOS/$NAME"

VERSION="${MARKETING_VERSION:-0.1.0}"; BUILD="${BUILD_NUMBER:-1}"
if [[ -n "$INFO_PLIST" && -f "$INFO_PLIST" ]]; then
  cp "$INFO_PLIST" "$CONTENTS/Info.plist"
else
  cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
EOF
  [[ -n "$ICON" ]] && echo "  <key>CFBundleIconFile</key><string>AppIcon</string>" >> "$CONTENTS/Info.plist"
  echo "</dict></plist>" >> "$CONTENTS/Info.plist"
fi

if [[ -n "$ICON" && -f "$ICON" ]]; then cp "$ICON" "$CONTENTS/Resources/AppIcon.icns"; fi

# Ad-hoc sign (stable identifier so TCC grants are less churny across rebuilds).
echo "==> ad-hoc codesign"
SIGN_ARGS=(--force --sign - --identifier "$BUNDLE_ID" --timestamp=none)
[[ -n "$ENTITLEMENTS" && -f "$ENTITLEMENTS" ]] && SIGN_ARGS+=(--entitlements "$ENTITLEMENTS")
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --verbose=1 "$APP" || true
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo "==> built: $APP"
if [[ "$DO_OPEN" -eq 1 ]]; then echo "==> launching"; open "$APP"; fi
