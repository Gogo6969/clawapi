#!/bin/bash
# build-release.sh — Build ClawAPI release and package as ZIP for distribution
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build/arm64-apple-macosx/release"
APP_NAME="ClawAPI.app"
APP_DIR="$BUILD_DIR/$APP_NAME"

# Extract version from AppVersion.swift (single source of truth)
VERSION_FILE="$SCRIPT_DIR/Sources/Shared/AppVersion.swift"
APP_VERSION=$(sed -n 's/.*static let current = "\(.*\)"/\1/p' "$VERSION_FILE")
BUILD_NUMBER=$(sed -n 's/.*static let build = "\(.*\)"/\1/p' "$VERSION_FILE")
echo "=== ClawAPI Release Build ==="
echo "Version: $APP_VERSION (build $BUILD_NUMBER)"
echo ""

# 1. Release build
echo "Building (release)..."
swift build -c release 2>&1 | tail -3

# 2. Assemble .app bundle
echo ""
echo "Assembling $APP_NAME..."
rm -rf "$APP_DIR"

mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/ClawAPIApp"   "$APP_DIR/Contents/MacOS/ClawAPIApp"
cp "$BUILD_DIR/ClawAPIDaemon" "$APP_DIR/Contents/MacOS/ClawAPIDaemon"

cp "$SCRIPT_DIR/Support/Info.plist" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$APP_VERSION" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP_DIR/Contents/Info.plist"

cp "$SCRIPT_DIR/Support/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$SCRIPT_DIR/Support/ClawAPI.entitlements" "$APP_DIR/Contents/Resources/ClawAPI.entitlements"

echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

# 3. Ad-hoc code sign with stable identifiers
#    (entitlements are NOT embedded — ad-hoc signing doesn't support keychain-access-groups)
echo "Code signing..."
codesign --force --sign - \
    --identifier "com.clawapi.daemon" \
    "$APP_DIR/Contents/MacOS/ClawAPIDaemon"

codesign --force --sign - \
    --identifier "com.clawapi.app" \
    "$APP_DIR/Contents/MacOS/ClawAPIApp"

codesign --force --sign - \
    --identifier "com.clawapi.app" \
    "$APP_DIR"

# 4. Create ZIP for distribution
DIST_DIR="$SCRIPT_DIR/dist"
mkdir -p "$DIST_DIR"
ZIP_NAME="ClawAPI-${APP_VERSION}.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

echo "Packaging $ZIP_NAME..."
rm -f "$ZIP_PATH"
cd "$BUILD_DIR"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_NAME" "$ZIP_PATH"
cd "$SCRIPT_DIR"

ZIP_SIZE=$(du -sh "$ZIP_PATH" | cut -f1)
SHA256=$(shasum -a 256 "$ZIP_PATH" | cut -d' ' -f1)

echo ""
echo "=== Release Ready ==="
echo "App:     $APP_DIR"
echo "ZIP:     $ZIP_PATH ($ZIP_SIZE)"
echo "SHA-256: $SHA256"
echo ""
echo "Next steps:"
echo "  1. gh release create v$APP_VERSION dist/$ZIP_NAME --title \"ClawAPI $APP_VERSION\" --notes \"...\""
echo "  2. Update update.json with new version and SHA-256"
