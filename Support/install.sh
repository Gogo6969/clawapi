#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_NAME="com.clawapi.daemon.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

echo "=== ClawAPI Daemon Installer ==="

# Create LaunchAgents directory if needed
mkdir -p "$LAUNCH_AGENTS_DIR"

# Copy plist
cp "$SCRIPT_DIR/$PLIST_NAME" "$LAUNCH_AGENTS_DIR/$PLIST_NAME"
echo "Installed $PLIST_NAME to $LAUNCH_AGENTS_DIR"

# Create data directory
mkdir -p "$HOME/Library/Application Support/ClawAPI"
echo "Created data directory"

# Load the agent
launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
echo "Loaded launch agent"

echo ""
echo "Done. The daemon will start on next login."
echo "To start it now: launchctl start com.clawapi.daemon"
