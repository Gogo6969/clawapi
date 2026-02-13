#!/bin/bash
set -euo pipefail

PLIST_NAME="com.clawapi.daemon.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

echo "=== ClawAPI Daemon Uninstaller ==="

# Unload the agent
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
echo "Unloaded launch agent"

# Remove plist
rm -f "$LAUNCH_AGENTS_DIR/$PLIST_NAME"
echo "Removed $PLIST_NAME"

echo ""
echo "Done. Data in ~/Library/Application Support/ClawAPI/ was preserved."
echo "Remove it manually if you want a clean uninstall."
