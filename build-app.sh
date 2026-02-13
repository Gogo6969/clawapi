#!/bin/bash
# build-app.sh — Build ClawAPI and package as a macOS .app bundle
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build/arm64-apple-macosx/debug"
APP_NAME="ClawAPI.app"
APP_DIR="$BUILD_DIR/$APP_NAME"

# Extract version from AppVersion.swift (single source of truth)
VERSION_FILE="$SCRIPT_DIR/Sources/Shared/AppVersion.swift"
APP_VERSION=$(sed -n 's/.*static let current = "\(.*\)"/\1/p' "$VERSION_FILE")
BUILD_NUMBER=$(sed -n 's/.*static let build = "\(.*\)"/\1/p' "$VERSION_FILE")
echo "Version: $APP_VERSION (build $BUILD_NUMBER)"

echo "Building ClawAPI..."
swift build

echo "Assembling $APP_NAME..."

# Clean previous bundle
rm -rf "$APP_DIR"

# Create bundle structure
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executables (app + daemon — daemon must be next to the app binary for MCPorter registration)
cp "$BUILD_DIR/ClawAPIApp" "$APP_DIR/Contents/MacOS/ClawAPIApp"
cp "$BUILD_DIR/ClawAPIDaemon" "$APP_DIR/Contents/MacOS/ClawAPIDaemon"

# Copy Info.plist and stamp version
cp "$SCRIPT_DIR/Support/Info.plist" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$APP_VERSION" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP_DIR/Contents/Info.plist"

# Copy app icon
cp "$SCRIPT_DIR/Support/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

# Copy entitlements if codesigning later
cp "$SCRIPT_DIR/Support/ClawAPI.entitlements" "$APP_DIR/Contents/Resources/ClawAPI.entitlements"

# Write PkgInfo
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

echo "Done: $APP_DIR"
echo ""
echo "Launch with:  open \"$APP_DIR\""
