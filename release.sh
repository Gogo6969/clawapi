#!/bin/bash
# release.sh — Build ClawAPI in release mode, package as .app, zip, and print SHA-256
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build/arm64-apple-macosx/release"
APP_NAME="ClawAPI.app"
APP_DIR="$BUILD_DIR/$APP_NAME"
DIST_DIR="$SCRIPT_DIR/dist"

# Extract version from AppVersion.swift (single source of truth)
VERSION_FILE="$SCRIPT_DIR/Sources/Shared/AppVersion.swift"
APP_VERSION=$(sed -n 's/.*static let current = "\(.*\)"/\1/p' "$VERSION_FILE")
BUILD_NUMBER=$(sed -n 's/.*static let build = "\(.*\)"/\1/p' "$VERSION_FILE")

echo "=== ClawAPI Release Build ==="
echo "Version: $APP_VERSION (build $BUILD_NUMBER)"
echo ""

# 1. Build in release mode
echo "Building (release mode)..."
swift build -c release 2>&1
echo ""

# 2. Assemble .app bundle
echo "Assembling $APP_NAME..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executables
cp "$BUILD_DIR/ClawAPIApp" "$APP_DIR/Contents/MacOS/ClawAPIApp"
cp "$BUILD_DIR/ClawAPIDaemon" "$APP_DIR/Contents/MacOS/ClawAPIDaemon"

# Copy Info.plist and stamp version
cp "$SCRIPT_DIR/Support/Info.plist" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$APP_VERSION" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP_DIR/Contents/Info.plist"

# Copy app icon
cp "$SCRIPT_DIR/Support/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

# Copy entitlements
cp "$SCRIPT_DIR/Support/ClawAPI.entitlements" "$APP_DIR/Contents/Resources/ClawAPI.entitlements"

# Write PkgInfo
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

# 3. Ad-hoc code sign (avoids "damaged" warnings on modern macOS)
echo "Code signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_DIR"
echo ""

# 4. Create zip for distribution
echo "Packaging..."
mkdir -p "$DIST_DIR"
ZIP_NAME="ClawAPI-${APP_VERSION}.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
rm -f "$ZIP_PATH"

# Use ditto to create a proper macOS zip that preserves extended attributes
/usr/bin/ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

# 5. Compute SHA-256
SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
ZIP_SIZE=$(du -h "$ZIP_PATH" | awk '{print $1}')

echo ""
echo "=== Release Ready ==="
echo "App:      $APP_DIR"
echo "Zip:      $ZIP_PATH ($ZIP_SIZE)"
echo "SHA-256:  $SHA256"
echo "Version:  $APP_VERSION (build $BUILD_NUMBER)"
echo ""
echo "=== update.json ==="
cat <<EOF
{
  "version": "$APP_VERSION",
  "build": "$BUILD_NUMBER",
  "minimumSystemVersion": "14.0",
  "releaseNotes": "Initial release of ClawAPI.",
  "downloadURL": "https://github.com/Gogo6969/clawapi/releases/download/v${APP_VERSION}/${ZIP_NAME}",
  "sha256": "$SHA256"
}
EOF
echo ""
echo "=== Next Steps ==="
echo "1. Create GitHub repo and push code"
echo "2. Create release: gh release create v${APP_VERSION} '$ZIP_PATH' --title 'ClawAPI ${APP_VERSION}' --notes 'Initial release'"
echo "3. Copy the update.json above, replace OWNER with your GitHub username, and commit it to the repo root"
echo "4. Update AppVersion.swift updateManifestURL to match your repo"
