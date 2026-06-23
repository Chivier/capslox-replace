#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_PATH="$ROOT_DIR/dist/CapsMov.dmg"
VOLUME_NAME="CapsMov"

usage() {
  cat <<'USAGE'
Usage: scripts/build-dmg.sh [--output PATH]

Builds a compressed CapsMov DMG containing CapsMov.app and autostart helpers.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_PATH="${2:?missing value for --output}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT

"$ROOT_DIR/scripts/build-app.sh" --output "$STAGE_DIR/CapsMov.app"

cp "$ROOT_DIR/packaging/Install Autostart.command" "$STAGE_DIR/Install Autostart.command"
cp "$ROOT_DIR/packaging/Uninstall Autostart.command" "$STAGE_DIR/Uninstall Autostart.command"
chmod +x "$STAGE_DIR/Install Autostart.command" "$STAGE_DIR/Uninstall Autostart.command"
ln -s /Applications "$STAGE_DIR/Applications"

mkdir -p "$(dirname "$OUTPUT_PATH")"
rm -f "$OUTPUT_PATH"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$OUTPUT_PATH" >/dev/null

echo "Built $OUTPUT_PATH"
