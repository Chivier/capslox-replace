#!/usr/bin/env bash
set -euo pipefail

LABEL="com.capsmov.app"
LEGACY_LABEL="com.capslox.app"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
LEGACY_PLIST_PATH="$HOME/Library/LaunchAgents/$LEGACY_LABEL.plist"

launchctl bootout "gui/$(id -u)" "$PLIST_PATH" >/dev/null 2>&1 || true
launchctl bootout "gui/$(id -u)" "$LEGACY_PLIST_PATH" >/dev/null 2>&1 || true
rm -f "$PLIST_PATH"
rm -f "$LEGACY_PLIST_PATH"

echo "Removed CapsMov autostart LaunchAgent."
echo "CapsMov.app was left installed. Remove $HOME/Applications/CapsMov.app manually if you no longer want the app."
