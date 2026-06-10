#!/usr/bin/env bash
set -euo pipefail

RULE_DESCRIPTION="Capslox Basic Navigation (CapsLock + E/D/S/F/I/K/J/L)"
KARABINER_DIR="${HOME}/.config/karabiner"
ASSETS_DIR="${KARABINER_DIR}/assets/complex_modifications"
ASSET_FILE="${ASSETS_DIR}/capslox-basic-navigation.json"
CONFIG_FILE="${KARABINER_DIR}/karabiner.json"
KARABINER_CLI="/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
ENABLE_RULE=1
OPEN_APP=1
SWAP_CONTROL_GLOBE=0
FIX_IQUNIX_ZONEX75=0
ENABLE_COMPOSITE_KEYBOARDS=1

usage() {
  cat <<'USAGE'
Usage: ./install-macos-karabiner.sh [--asset-only] [--no-open] [--swap-control-globe] [--fix-iqunix-zonex75] [--no-enable-composite-keyboards]

Installs a Karabiner-Elements rule for:
  Caps Lock + E/D/S/F -> Up/Down/Left/Right
  Caps Lock + I/K/J/L -> PageUp/PageDown/Home/End

Options:
  --asset-only  Only write the complex-modification JSON asset; do not edit karabiner.json.
  --no-open     Do not open Karabiner-Elements after installing.
  --swap-control-globe
               Swap Fn/Globe and Control only on the built-in keyboard.
               External keyboards keep their own modifier settings.
  --fix-iqunix-zonex75
               Normalize the IQUNIX ZONEX75 right-side modifiers:
                 Right Command -> Right Option
                 Right Option  -> Right Control
                 keyboard_fn    -> Right Control
  --no-enable-composite-keyboards
               Do not auto-enable "Modify events" for connected external
               keyboards that also report a pointing-device interface.
               Karabiner ignores such composite devices by default, which
               silently disables all rules on those keyboards.
  -h, --help    Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --asset-only)
      ENABLE_RULE=0
      ;;
    --no-open)
      OPEN_APP=0
      ;;
    --swap-control-globe)
      SWAP_CONTROL_GLOBE=1
      ;;
    --fix-iqunix-zonex75)
      FIX_IQUNIX_ZONEX75=1
      ;;
    --no-enable-composite-keyboards)
      ENABLE_COMPOSITE_KEYBOARDS=0
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
  shift
done

write_rule_json() {
  local target="$1"
  cat >"${target}" <<'JSON'
{
  "title": "Capslox Basic Navigation",
  "rules": [
    {
      "description": "Capslox Basic Navigation (CapsLock + E/D/S/F/I/K/J/L)",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "key_code": "caps_lock",
            "modifiers": {
              "optional": [
                "any"
              ]
            }
          },
          "to": [
            {
              "set_variable": {
                "name": "capslox_mode",
                "value": 1
              }
            }
          ],
          "to_after_key_up": [
            {
              "set_variable": {
                "name": "capslox_mode",
                "value": 0
              }
            }
          ],
          "to_if_alone": [
            {
              "key_code": "caps_lock"
            }
          ],
          "parameters": {
            "basic.to_if_alone_timeout_milliseconds": 250
          }
        },
        {
          "type": "basic",
          "from": {
            "key_code": "e",
            "modifiers": {
              "optional": [
                "any"
              ]
            }
          },
          "to": [
            {
              "key_code": "up_arrow"
            }
          ],
          "conditions": [
            {
              "type": "variable_if",
              "name": "capslox_mode",
              "value": 1
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key_code": "d",
            "modifiers": {
              "optional": [
                "any"
              ]
            }
          },
          "to": [
            {
              "key_code": "down_arrow"
            }
          ],
          "conditions": [
            {
              "type": "variable_if",
              "name": "capslox_mode",
              "value": 1
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key_code": "s",
            "modifiers": {
              "optional": [
                "any"
              ]
            }
          },
          "to": [
            {
              "key_code": "left_arrow"
            }
          ],
          "conditions": [
            {
              "type": "variable_if",
              "name": "capslox_mode",
              "value": 1
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key_code": "f",
            "modifiers": {
              "optional": [
                "any"
              ]
            }
          },
          "to": [
            {
              "key_code": "right_arrow"
            }
          ],
          "conditions": [
            {
              "type": "variable_if",
              "name": "capslox_mode",
              "value": 1
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key_code": "i",
            "modifiers": {
              "optional": [
                "any"
              ]
            }
          },
          "to": [
            {
              "key_code": "page_up"
            }
          ],
          "conditions": [
            {
              "type": "variable_if",
              "name": "capslox_mode",
              "value": 1
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key_code": "k",
            "modifiers": {
              "optional": [
                "any"
              ]
            }
          },
          "to": [
            {
              "key_code": "page_down"
            }
          ],
          "conditions": [
            {
              "type": "variable_if",
              "name": "capslox_mode",
              "value": 1
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key_code": "j",
            "modifiers": {
              "optional": [
                "any"
              ]
            }
          },
          "to": [
            {
              "key_code": "home"
            }
          ],
          "conditions": [
            {
              "type": "variable_if",
              "name": "capslox_mode",
              "value": 1
            }
          ]
        },
        {
          "type": "basic",
          "from": {
            "key_code": "l",
            "modifiers": {
              "optional": [
                "any"
              ]
            }
          },
          "to": [
            {
              "key_code": "end"
            }
          ],
          "conditions": [
            {
              "type": "variable_if",
              "name": "capslox_mode",
              "value": 1
            }
          ]
        }
      ]
    }
  ]
}
JSON
}

karabiner_installed() {
  [[ -d "/Applications/Karabiner-Elements.app" ]] ||
    [[ -d "/Library/Application Support/org.pqrs/Karabiner-Elements" ]]
}

# Connected-device list as JSON, in `karabiner_cli --list-connected-devices`
# format. CAPSLOX_CONNECTED_DEVICES_JSON overrides for tests.
connected_devices_json() {
  if [[ -n "${CAPSLOX_CONNECTED_DEVICES_JSON:-}" ]]; then
    printf '%s' "${CAPSLOX_CONNECTED_DEVICES_JSON}"
  elif [[ -x "${KARABINER_CLI}" ]]; then
    "${KARABINER_CLI}" --list-connected-devices 2>/dev/null || true
  fi
}

mkdir -p "${ASSETS_DIR}"
tmp_rule="$(mktemp)"
trap 'rm -f "${tmp_rule}"' EXIT
write_rule_json "${tmp_rule}"
install -m 0644 "${tmp_rule}" "${ASSET_FILE}"
echo "Wrote complex-modification asset: ${ASSET_FILE}"

if ! karabiner_installed; then
  cat >&2 <<'WARN'

Karabiner-Elements does not appear to be installed.
Install it first:
  brew install --cask karabiner-elements

The rule asset was written, but it cannot take effect until Karabiner-Elements is installed and running.
WARN
  exit 0
fi

if [[ "${ENABLE_RULE}" -eq 1 ]]; then
  if ! command -v python3 >/dev/null 2>&1; then
    cat >&2 <<WARN

python3 was not found, so karabiner.json was not edited.
Open Karabiner-Elements > Complex Modifications > Add rule, then enable:
  ${RULE_DESCRIPTION}
WARN
  else
    CONFIG_FILE="${CONFIG_FILE}" ASSET_FILE="${ASSET_FILE}" SWAP_CONTROL_GLOBE="${SWAP_CONTROL_GLOBE}" FIX_IQUNIX_ZONEX75="${FIX_IQUNIX_ZONEX75}" ENABLE_COMPOSITE_KEYBOARDS="${ENABLE_COMPOSITE_KEYBOARDS}" CONNECTED_DEVICES_JSON="$(connected_devices_json)" python3 <<'PY'
import datetime
import json
import os
import shutil
from pathlib import Path

config_path = Path(os.environ["CONFIG_FILE"]).expanduser()
asset_path = Path(os.environ["ASSET_FILE"]).expanduser()
rule_doc = json.loads(asset_path.read_text())
new_rules = rule_doc["rules"]
if os.environ.get("SWAP_CONTROL_GLOBE") == "1":
    built_in_keyboard_condition = {
        "type": "device_if",
        "identifiers": [
            {
                "is_built_in_keyboard": True
            }
        ]
    }
    new_rules = [
        *new_rules,
        {
            "description": "Swap Fn/Globe and Control on the built-in keyboard only",
            "manipulators": [
                {
                    "type": "basic",
                    "from": {
                        "apple_vendor_top_case_key_code": "keyboard_fn",
                        "modifiers": {
                            "optional": [
                                "any"
                            ]
                        }
                    },
                    "to": [
                        {
                            "key_code": "left_control"
                        }
                    ],
                    "conditions": [
                        built_in_keyboard_condition
                    ]
                },
                {
                    "type": "basic",
                    "from": {
                        "key_code": "left_control",
                        "modifiers": {
                            "optional": [
                                "any"
                            ]
                        }
                    },
                    "to": [
                        {
                            "apple_vendor_top_case_key_code": "keyboard_fn"
                        }
                    ],
                    "conditions": [
                        built_in_keyboard_condition
                    ]
                }
            ]
        }
    ]
if os.environ.get("FIX_IQUNIX_ZONEX75") == "1":
    iqunix_zonex75_condition = {
        "type": "device_if",
        "identifiers": [
            {
                "vendor_id": 12815,
                "product_id": 20754,
                "is_keyboard": True
            }
        ]
    }
    new_rules = [
        *new_rules,
        {
            "description": "Normalize IQUNIX ZONEX75 right-side modifiers",
            "manipulators": [
                {
                    "type": "basic",
                    "from": {
                        "key_code": "right_command",
                        "modifiers": {
                            "optional": [
                                "any"
                            ]
                        }
                    },
                    "to": [
                        {
                            "key_code": "right_option"
                        }
                    ],
                    "conditions": [
                        iqunix_zonex75_condition
                    ]
                },
                {
                    "type": "basic",
                    "from": {
                        "key_code": "right_option",
                        "modifiers": {
                            "optional": [
                                "any"
                            ]
                        }
                    },
                    "to": [
                        {
                            "key_code": "right_control"
                        }
                    ],
                    "conditions": [
                        iqunix_zonex75_condition
                    ]
                },
                {
                    "type": "basic",
                    "from": {
                        "apple_vendor_top_case_key_code": "keyboard_fn",
                        "modifiers": {
                            "optional": [
                                "any"
                            ]
                        }
                    },
                    "to": [
                        {
                            "key_code": "right_control"
                        }
                    ],
                    "conditions": [
                        iqunix_zonex75_condition
                    ]
                }
            ]
        }
    ]
new_descriptions = {rule["description"] for rule in new_rules}

created_config = False
if config_path.exists():
    config = json.loads(config_path.read_text())
else:
    created_config = True
    config = {
        "profiles": [
            {
                "name": "Default profile",
                "selected": True,
                "complex_modifications": {
                    "rules": []
                }
            }
        ]
    }

profiles = config.setdefault("profiles", [])
if not profiles:
    profiles.append({
        "name": "Default profile",
        "selected": True,
        "complex_modifications": {
            "rules": []
        }
    })

profile = next((item for item in profiles if item.get("selected")), profiles[0])
complex_modifications = profile.setdefault("complex_modifications", {})
rules = complex_modifications.setdefault("rules", [])

filtered_rules = [
    rule for rule in rules
    if rule.get("description") not in new_descriptions
]
filtered_rules.extend(new_rules)
complex_modifications["rules"] = filtered_rules

# Karabiner ignores devices that report a pointing-device interface by
# default ("Modify events" off), even when they are keyboards. Such
# composite external keyboards (e.g. IQUNIX MQ80 over Bluetooth) silently
# get no complex modifications. Add explicit ignore:false entries for
# connected composite keyboards so the rules actually apply to them.
enabled_keyboards = []
skipped_disabled_keyboards = []
if os.environ.get("ENABLE_COMPOSITE_KEYBOARDS") == "1":
    import re

    try:
        connected = json.loads(os.environ.get("CONNECTED_DEVICES_JSON") or "[]")
    except json.JSONDecodeError:
        connected = []

    pointer_name = re.compile(r"mouse|trackpad|touchpad", re.IGNORECASE)
    devices = profile.setdefault("devices", [])

    def entry_key(identifiers):
        return (
            identifiers.get("vendor_id"),
            identifiers.get("product_id"),
            bool(identifiers.get("is_keyboard")),
            bool(identifiers.get("is_pointing_device")),
        )

    for device in connected:
        identifiers = device.get("device_identifiers", {})
        if not identifiers.get("is_keyboard"):
            continue
        if not identifiers.get("is_pointing_device"):
            continue  # plain keyboards are modified by default
        if identifiers.get("is_virtual_device"):
            continue
        if device.get("is_built_in_keyboard") or device.get("is_apple"):
            continue
        if "vendor_id" not in identifiers or "product_id" not in identifiers:
            continue
        product = device.get("product", "")
        if pointer_name.search(product):
            continue  # composite device that is actually a mouse-like device

        existing = next(
            (
                item for item in devices
                if entry_key(item.get("identifiers", {})) == entry_key(identifiers)
            ),
            None,
        )
        if existing is None:
            devices.append({
                "identifiers": {
                    "is_keyboard": True,
                    "is_pointing_device": True,
                    "vendor_id": identifiers["vendor_id"],
                    "product_id": identifiers["product_id"],
                },
                "ignore": False,
            })
            enabled_keyboards.append(product or str(entry_key(identifiers)))
        elif existing.get("ignore") is True:
            # Respect an explicit user choice, but tell them why rules fail.
            skipped_disabled_keyboards.append(product or str(entry_key(identifiers)))

if os.environ.get("SWAP_CONTROL_GLOBE") == "1":
    simple_modifications = profile.setdefault("simple_modifications", [])
    if not isinstance(simple_modifications, list):
        raise TypeError("profile.simple_modifications must be a list")

    old_profile_level_swaps = [
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
                "key_code": "fn"
            },
            "to": [
                {
                    "key_code": "left_control"
                }
            ]
        }
    ]
    old_profile_level_swap_keys = {
        json.dumps(
            {"from": item.get("from", {}), "to": item.get("to", [])},
            sort_keys=True,
        )
        for item in old_profile_level_swaps
    }
    simple_modifications[:] = [
        item for item in simple_modifications
        if json.dumps(
            {"from": item.get("from", {}), "to": item.get("to", [])},
            sort_keys=True,
        ) not in old_profile_level_swap_keys
    ]

config_path.parent.mkdir(parents=True, exist_ok=True)
backup_path = None
if config_path.exists():
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = config_path.with_name(f"{config_path.name}.{stamp}.bak")
    shutil.copy2(config_path, backup_path)

tmp_path = config_path.with_suffix(".json.tmp")
tmp_path.write_text(json.dumps(config, indent=2, ensure_ascii=False) + "\n")
tmp_path.replace(config_path)

print(f"Enabled rule in profile: {profile.get('name', 'Default profile')}")
if os.environ.get("SWAP_CONTROL_GLOBE") == "1":
    print("Enabled built-in keyboard Fn/Globe <-> Control rule")
if os.environ.get("FIX_IQUNIX_ZONEX75") == "1":
    print("Enabled IQUNIX ZONEX75 right-side modifier normalization rule")
for name in enabled_keyboards:
    print(f"Enabled 'Modify events' for composite keyboard: {name}")
for name in skipped_disabled_keyboards:
    print(
        f"Warning: '{name}' has 'Modify events' explicitly disabled in Karabiner; "
        "Capslox rules will not work on it until you re-enable it."
    )
if backup_path:
    print(f"Backup: {backup_path}")
elif created_config:
    print(f"Created config: {config_path}")
PY
  fi
else
  cat <<WARN
Asset-only mode selected.
Open Karabiner-Elements > Complex Modifications > Add rule, then enable:
  ${RULE_DESCRIPTION}
WARN
fi

if [[ "${OPEN_APP}" -eq 1 ]]; then
  open -a "Karabiner-Elements" >/dev/null 2>&1 || true
fi

cat <<'DONE'

Done.
If the mapping does not work immediately:
  1. Make sure Karabiner-Elements has Input Monitoring permission.
  2. Restart Karabiner-Elements.
  3. Check Karabiner-Elements > Complex Modifications and confirm the Capslox Basic Navigation rule is enabled.
DONE
