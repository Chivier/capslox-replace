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
      "simple_modifications": [
        {
          "from": {
            "key_code": "left_control"
          },
          "to": [
            {
              "apple_vendor_top_case_key_code": "keyboard_fn"
            }
          ]
        },
        {
          "from": {
            "apple_vendor_top_case_key_code": "keyboard_fn"
          },
          "to": [
            {
              "key_code": "left_control"
            }
          ]
        },
        {
          "from": {
            "key_code": "fn"
          },
          "to": [
            {
              "key_code": "left_control"
            }
          ]
        },
        {
          "from": {
            "key_code": "left_control"
          },
          "to": [
            {
              "key_code": "escape"
            }
          ]
        },
        {
          "from": {
            "key_code": "fn"
          },
          "to": [
            {
              "key_code": "f19"
            }
          ]
        },
        {
          "from": {
            "apple_vendor_top_case_key_code": "keyboard_fn"
          },
          "to": [
            {
              "key_code": "delete_or_backspace"
            }
          ]
        },
        {
          "from": {
            "key_code": "left_control"
          },
          "to": [
            {
              "key_code": "fn"
            }
          ]
        },
        {
          "from": {
            "key_code": "right_command"
          },
          "to": [
            {
              "key_code": "right_option"
            }
          ]
        }
      ]
    }
  ]
}
JSON

HOME="${tmp_home}" "${repo_root}/install-macos-karabiner.sh" \
  --swap-control-globe \
  --no-open >/dev/null

CONFIG_FILE="${tmp_home}/.config/karabiner/karabiner.json" python3 <<'PY'
import json
import os
from pathlib import Path

config = json.loads(Path(os.environ["CONFIG_FILE"]).read_text())
profile = next((item for item in config["profiles"] if item.get("selected")), config["profiles"][0])
simple_modifications = profile.get("simple_modifications", [])
rules = profile.get("complex_modifications", {}).get("rules", [])


def has_mapping(from_value, to_value):
    return any(
        item.get("from") == from_value and item.get("to") == [to_value]
        for item in simple_modifications
    )


capslox_rule = next(
    (
        rule for rule in rules
        if rule.get("description") == "Capslox Basic Navigation (CapsLock + E/D/S/F/I/K/J/L)"
    ),
    None,
)
assert capslox_rule, "Capslox Basic Navigation rule should be enabled"

capslock_manipulator = next(
    (
        manipulator for manipulator in capslox_rule.get("manipulators", [])
        if manipulator.get("from", {}).get("key_code") == "caps_lock"
    ),
    None,
)
assert capslock_manipulator, "Caps Lock layer manipulator should exist"
assert "to_if_alone" not in capslock_manipulator, "Caps Lock alone should not toggle Caps Lock"


def capslox_mapping(from_key):
    for manipulator in capslox_rule.get("manipulators", []):
        if manipulator.get("from", {}).get("key_code") == from_key:
            return manipulator.get("to")
    return None


assert capslox_mapping("i") == [
    {"key_code": "page_up"},
], "Caps Lock + I should emit Page Up"

assert capslox_mapping("k") == [
    {"key_code": "page_down"},
], "Caps Lock + K should emit Page Down"

assert capslox_mapping("j") == [
    {"key_code": "left_arrow", "modifiers": ["left_command"]},
], "Caps Lock + J should move to line start on macOS"

assert capslox_mapping("l") == [
    {"key_code": "right_arrow", "modifiers": ["left_command"]},
], "Caps Lock + L should move to line end on macOS"

assert not has_mapping(
    {"apple_vendor_top_case_key_code": "keyboard_fn"},
    {"key_code": "left_control"},
), "Apple Globe/Fn should not be mapped at profile level"

assert not has_mapping(
    {"key_code": "fn"},
    {"key_code": "left_control"},
), "Generic fn should not be mapped at profile level because it affects external keyboards"

assert not has_mapping(
    {"key_code": "left_control"},
    {"key_code": "fn"},
), "left_control should stay left_control so external Ctrl+C keeps working"

assert not has_mapping(
    {"key_code": "left_control"},
    {"apple_vendor_top_case_key_code": "keyboard_fn"},
), "left_control should not map to Apple top-case fn"

assert has_mapping(
    {"key_code": "left_control"},
    {"key_code": "escape"},
), "unrelated left_control simple modifications should be preserved"

assert has_mapping(
    {"key_code": "fn"},
    {"key_code": "f19"},
), "unrelated fn simple modifications should be preserved"

assert has_mapping(
    {"apple_vendor_top_case_key_code": "keyboard_fn"},
    {"key_code": "delete_or_backspace"},
), "unrelated Apple top-case fn simple modifications should be preserved"

assert has_mapping(
    {"key_code": "right_command"},
    {"key_code": "right_option"},
), "unrelated simple modifications should be preserved"

modifier_rule = next(
    (
        rule for rule in rules
        if rule.get("description") == "Swap Fn/Globe and Control on the built-in keyboard only"
    ),
    None,
)
assert modifier_rule, "built-in-only modifier rule should be enabled"


def manipulator_exists(from_value, to_value):
    for manipulator in modifier_rule.get("manipulators", []):
        if manipulator.get("from") != from_value:
            continue
        if manipulator.get("to") != [to_value]:
            continue
        if manipulator.get("conditions") != [
            {
                "type": "device_if",
                "identifiers": [
                    {
                        "is_built_in_keyboard": True,
                    }
                ],
            }
        ]:
            continue
        return True
    return False


assert manipulator_exists(
    {
        "apple_vendor_top_case_key_code": "keyboard_fn",
        "modifiers": {
            "optional": [
                "any",
            ],
        },
    },
    {"key_code": "left_control"},
), "built-in Fn/Globe should become Control"

assert manipulator_exists(
    {
        "key_code": "left_control",
        "modifiers": {
            "optional": [
                "any",
            ],
        },
    },
    {"apple_vendor_top_case_key_code": "keyboard_fn"},
), "built-in Control should become Fn/Globe"
PY

echo "ok: swap-control-globe config is built-in-keyboard scoped"
