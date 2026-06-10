#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -d "/Applications/Karabiner-Elements.app" ]] &&
  [[ ! -d "/Library/Application Support/org.pqrs/Karabiner-Elements" ]]; then
  echo "skip: Karabiner-Elements is not installed"
  exit 0
fi

tmp_home="$(mktemp -d)"
trap 'rm -rf "${tmp_home}"' EXIT

mkdir -p "${tmp_home}/.config/karabiner"
cat >"${tmp_home}/.config/karabiner/karabiner.json" <<'JSON'
{
  "profiles": [
    {
      "name": "Default profile",
      "selected": true,
      "devices": [
        {
          "identifiers": {
            "is_keyboard": true,
            "is_pointing_device": true,
            "vendor_id": 12815,
            "product_id": 20754
          },
          "ignore": false
        }
      ]
    }
  ]
}
JSON

# Simulated `karabiner_cli --list-connected-devices` output:
# - IQUNIX MQ80 KB BT1: composite keyboard+pointing device -> must be enabled
# - BT5.1 Mouse: composite but named like a mouse -> must NOT be touched
# - Mi USB Receiver keyboard: plain keyboard -> already modified by default, no entry needed
# - IQUNIX ZONEX75: composite, already has an ignore:false entry -> no duplicate
# - Virtual / built-in devices -> must be skipped
connected_devices_json='[
  {"device_identifiers": {"is_keyboard": true}, "is_apple": true, "is_built_in_keyboard": true, "product": "Apple Internal Keyboard / Trackpad"},
  {"device_identifiers": {"is_keyboard": true, "is_pointing_device": true, "product_id": 33398, "vendor_id": 9306}, "product": "IQUNIX MQ80 KB BT1", "transport": "Bluetooth Low Energy"},
  {"device_identifiers": {"is_keyboard": true, "is_pointing_device": true, "product_id": 26145, "vendor_id": 12994}, "product": "BT5.1 Mouse", "transport": "Bluetooth Low Energy"},
  {"device_identifiers": {"is_keyboard": true, "product_id": 20625, "vendor_id": 10007}, "product": "Mi USB Receiver", "transport": "USB"},
  {"device_identifiers": {"is_keyboard": true, "is_pointing_device": true, "product_id": 20754, "vendor_id": 12815}, "product": "IQUNIX ZONEX75 Mechanical Keyboard", "transport": "USB"},
  {"device_identifiers": {"is_keyboard": true, "is_virtual_device": true, "product_id": 591, "vendor_id": 1452}, "product": "Karabiner DriverKit VirtualHIDKeyboard 1.8.0"}
]'

HOME="${tmp_home}" CAPSLOX_CONNECTED_DEVICES_JSON="${connected_devices_json}" \
  "${repo_root}/install-macos-karabiner.sh" --no-open >/dev/null

CONFIG_FILE="${tmp_home}/.config/karabiner/karabiner.json" python3 <<'PY'
import json
import os
from pathlib import Path

config = json.loads(Path(os.environ["CONFIG_FILE"]).read_text())
profile = next((item for item in config["profiles"] if item.get("selected")), config["profiles"][0])
devices = profile.get("devices", [])


def entries_for(vendor_id, product_id):
    return [
        item for item in devices
        if item.get("identifiers", {}).get("vendor_id") == vendor_id
        and item.get("identifiers", {}).get("product_id") == product_id
    ]


mq80 = entries_for(9306, 33398)
assert len(mq80) == 1, f"composite keyboard MQ80 should get exactly one device entry, got {len(mq80)}"
assert mq80[0].get("ignore") is False, "composite keyboard MQ80 should have ignore: false (Modify events on)"
assert mq80[0]["identifiers"].get("is_keyboard") is True
assert mq80[0]["identifiers"].get("is_pointing_device") is True

assert not entries_for(12994, 26145), "BT5.1 Mouse should not be enabled even though it reports a keyboard interface"

zonex = entries_for(12815, 20754)
assert len(zonex) == 1, f"existing ZONEX75 entry should not be duplicated, got {len(zonex)}"
assert zonex[0].get("ignore") is False, "existing ZONEX75 entry should keep ignore: false"

assert not entries_for(10007, 20625), "plain keyboards are modified by default and need no entry"

assert not entries_for(1452, 591), "virtual devices should be skipped"
PY

# Second run must be idempotent.
HOME="${tmp_home}" CAPSLOX_CONNECTED_DEVICES_JSON="${connected_devices_json}" \
  "${repo_root}/install-macos-karabiner.sh" --no-open >/dev/null

CONFIG_FILE="${tmp_home}/.config/karabiner/karabiner.json" python3 <<'PY'
import json
import os
from pathlib import Path

config = json.loads(Path(os.environ["CONFIG_FILE"]).read_text())
profile = next((item for item in config["profiles"] if item.get("selected")), config["profiles"][0])
devices = profile.get("devices", [])
mq80 = [
    item for item in devices
    if item.get("identifiers", {}).get("vendor_id") == 9306
    and item.get("identifiers", {}).get("product_id") == 33398
]
assert len(mq80) == 1, f"re-running the installer should not duplicate device entries, got {len(mq80)}"
PY

echo "ok: composite external keyboards get ignore:false device entries"
