#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CapsMov.app"
LABEL="com.capsmov.app"
LEGACY_APP_NAME="Capslox.app"
LEGACY_LABEL="com.capslox.app"
INSTALL_DIR="$HOME/Applications"
INSTALL_APP="$INSTALL_DIR/$APP_NAME"
LEGACY_APP="$INSTALL_DIR/$LEGACY_APP_NAME"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/$LABEL.plist"
LEGACY_PLIST_PATH="$PLIST_DIR/$LEGACY_LABEL.plist"
LOG_DIR="$HOME/Library/Logs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_APP="$SCRIPT_DIR/$APP_NAME"

if [[ ! -d "$SOURCE_APP" ]]; then
  echo "Could not find $APP_NAME next to this installer." >&2
  echo "Run this command from the mounted CapsMov DMG." >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR" "$PLIST_DIR" "$LOG_DIR"
launchctl bootout "gui/$(id -u)" "$LEGACY_PLIST_PATH" >/dev/null 2>&1 || true
rm -f "$LEGACY_PLIST_PATH"
rm -rf "$LEGACY_APP"

rm -rf "$INSTALL_APP"
cp -R "$SOURCE_APP" "$INSTALL_APP"

EXECUTABLE="$INSTALL_APP/Contents/MacOS/CapsMov"
if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Installed executable is missing: $EXECUTABLE" >&2
  exit 1
fi

launchctl bootout "gui/$(id -u)" "$PLIST_PATH" >/dev/null 2>&1 || true

if [[ -n "${CAPSLOX_TAP_THRESHOLD_MS:-}" ]]; then
  if ! [[ "$CAPSLOX_TAP_THRESHOLD_MS" =~ ^[0-9]+$ ]] || [[ "$CAPSLOX_TAP_THRESHOLD_MS" -eq 0 ]]; then
    echo "CAPSLOX_TAP_THRESHOLD_MS must be a positive integer." >&2
    exit 1
  fi
  ENVIRONMENT_BLOCK="
  <key>EnvironmentVariables</key>
  <dict>
    <key>CAPSLOX_TAP_THRESHOLD_MS</key>
    <string>${CAPSLOX_TAP_THRESHOLD_MS}</string>
  </dict>"
else
  ENVIRONMENT_BLOCK=""
fi

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$EXECUTABLE</string>
  </array>
  <key>RunAtLoad</key>
  <true/>$ENVIRONMENT_BLOCK
  <key>StandardOutPath</key>
  <string>$LOG_DIR/CapsMov.log</string>
  <key>StandardErrorPath</key>
  <string>$LOG_DIR/CapsMov.err.log</string>
</dict>
</plist>
PLIST

plutil -lint "$PLIST_PATH" >/dev/null
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
launchctl enable "gui/$(id -u)/$LABEL"
launchctl kickstart -k "gui/$(id -u)/$LABEL"

echo "Installed CapsMov to $INSTALL_APP"
echo "Installed autostart LaunchAgent at $PLIST_PATH"
echo ""
echo "CapsMov needs TWO permissions to work. Grant both for CapsMov:"
echo "  1. Accessibility     - lets CapsMov rewrite Caps Lock key combos."
echo "  2. Input Monitoring  - lets CapsMov read the physical Caps Lock state."
echo ""
echo "macOS should prompt for each on first launch. If it does not, add"
echo "$INSTALL_APP manually in System Settings > Privacy & Security."
echo "Opening both panes now..."

open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" >/dev/null 2>&1 || true
sleep 1
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent" >/dev/null 2>&1 || true
