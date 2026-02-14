#!/bin/bash
# ClawAPI installer — downloads and installs ClawAPI.app to /Applications
set -euo pipefail

REPO="Gogo6969/clawapi"
APP_NAME="ClawAPI.app"
INSTALL_DIR="/Applications"

echo ""
echo "  🦞 ClawAPI Installer"
echo ""

# Get latest release download URL
echo "  Fetching latest release..."
DOWNLOAD_URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep "browser_download_url.*\.zip" \
    | head -1 \
    | cut -d'"' -f4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "  ✗ No release found. Check https://github.com/$REPO/releases"
    exit 1
fi

VERSION=$(echo "$DOWNLOAD_URL" | grep -o 'ClawAPI-[0-9.]*' | sed 's/ClawAPI-//')
echo "  Latest version: $VERSION"

# Download
TMPDIR=$(mktemp -d)
ZIP_PATH="$TMPDIR/ClawAPI.zip"
echo "  Downloading..."
curl -fsSL -o "$ZIP_PATH" "$DOWNLOAD_URL"

# Kill running instance
if pgrep -f "ClawAPIApp" > /dev/null 2>&1; then
    echo "  Stopping running ClawAPI..."
    pkill -f "ClawAPIApp" 2>/dev/null || true
    sleep 0.5
fi

# Unzip and install
echo "  Installing to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR/$APP_NAME"
/usr/bin/ditto -x -k "$ZIP_PATH" "$INSTALL_DIR"

# Remove quarantine flag (prevents Gatekeeper popup)
xattr -cr "$INSTALL_DIR/$APP_NAME" 2>/dev/null || true

# Clean up
rm -rf "$TMPDIR"

echo ""
echo "  ✓ ClawAPI $VERSION installed to $INSTALL_DIR/$APP_NAME"
echo ""
echo "  Launch with:  open /Applications/ClawAPI.app"
echo "  Or press Cmd+Space and type 'ClawAPI'"
echo ""

# Offer to launch
read -p "  Launch ClawAPI now? [Y/n] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    open "$INSTALL_DIR/$APP_NAME"
    echo "  ✓ ClawAPI is running."
fi
echo ""
