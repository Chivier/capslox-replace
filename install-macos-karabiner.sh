#!/usr/bin/env bash
set -euo pipefail

RULE_DESCRIPTION="Capslox Basic Navigation (CapsLock + E/D/S/F/I/K/J/L)"
KARABINER_DIR="${HOME}/.config/karabiner"
ASSETS_DIR="${KARABINER_DIR}/assets/complex_modifications"
ASSET_FILE="${ASSETS_DIR}/capslox-basic-navigation.json"
CONFIG_FILE="${KARABINER_DIR}/karabiner.json"
ENABLE_RULE=1
OPEN_APP=1
SWAP_CONTROL_GLOBE=0

usage() {
  cat <<'USAGE'
Usage: ./install-macos-karabiner.sh [--asset-only] [--no-open] [--swap-control-globe]

Installs a Karabiner-Elements rule for:
  Caps Lock + E/D/S/F -> Up/Down/Left/Right
  Caps Lock + I/K/J/L -> PageUp/PageDown/Home/End

Options:
  --asset-only  Only write the complex-modification JSON asset; do not edit karabiner.json.
  --no-open     Do not open Karabiner-Elements after installing.
  --swap-control-globe
               Also add Karabiner Simple Modifications for:
                 Control -> Globe/Fn
                 Globe/Fn -> Control
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
    CONFIG_FILE="${CONFIG_FILE}" ASSET_FILE="${ASSET_FILE}" SWAP_CONTROL_GLOBE="${SWAP_CONTROL_GLOBE}" python3 <<'PY'
import datetime
import json
import os
import shutil
from pathlib import Path

config_path = Path(os.environ["CONFIG_FILE"]).expanduser()
asset_path = Path(os.environ["ASSET_FILE"]).expanduser()
rule_doc = json.loads(asset_path.read_text())
new_rules = rule_doc["rules"]
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

if os.environ.get("SWAP_CONTROL_GLOBE") == "1":
    simple_modifications = profile.setdefault("simple_modifications", [])
    if not isinstance(simple_modifications, list):
        raise TypeError("profile.simple_modifications must be a list")

    swap_modifications = [
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
        }
    ]
    swap_froms = {
        json.dumps(item["from"], sort_keys=True)
        for item in swap_modifications
    }
    simple_modifications[:] = [
        item for item in simple_modifications
        if json.dumps(item.get("from", {}), sort_keys=True) not in swap_froms
    ]
    simple_modifications.extend(swap_modifications)

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
    print("Added Simple Modifications: Control <-> Globe/Fn")
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
