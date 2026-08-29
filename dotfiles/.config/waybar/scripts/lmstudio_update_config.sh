#!/usr/bin/env bash
# Generate a validated machine-local Waybar config and LM Studio menu set.

set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar"
TEMPLATE_CONFIG_FILE="${WAYBAR_TEMPLATE_CONFIG:-$HOME/.config/waybar/config.jsonc}"
GENERATED_CONFIG_FILE="${WAYBAR_GENERATED_CONFIG:-$CACHE_DIR/config.generated.jsonc}"
MENU_FILE="${LMSTUDIO_MENU_FILE:-$CACHE_DIR/lmstudio_menu.xml}"
MENU_ACTIONS_FILE="${LMSTUDIO_MENU_ACTIONS_FILE:-$CACHE_DIR/lmstudio_menu_actions.jsonc}"
TEMP_RESOLVER="${HOME}/.config/waybar/scripts/temperature_resolve_path.sh"
GENERATOR="${HOME}/.config/waybar/scripts/lmstudio_generate_menu.sh"

mkdir -p "$CACHE_DIR" \
    "$(dirname "$GENERATED_CONFIG_FILE")" \
    "$(dirname "$MENU_FILE")" \
    "$(dirname "$MENU_ACTIONS_FILE")"

staged_menu="$(mktemp "${MENU_FILE}.tmp.XXXXXX")"
staged_actions="$(mktemp "${MENU_ACTIONS_FILE}.tmp.XXXXXX")"
staged_config="$(mktemp "${GENERATED_CONFIG_FILE}.tmp.XXXXXX")"
cleanup() {
    rm -f "$staged_menu" "$staged_actions" "$staged_config"
}
trap cleanup EXIT

TEMP_HWMON_PATH="$("$TEMP_RESOLVER" 2>/dev/null || true)"
if [[ -n "$TEMP_HWMON_PATH" && -r "$TEMP_HWMON_PATH" ]]; then
    printf '%s\n' "$TEMP_HWMON_PATH" >"$CACHE_DIR/temperature_hwmon_path"
else
    : >"$CACHE_DIR/temperature_hwmon_path"
fi
export TEMP_HWMON_PATH

# Generate into staged paths. Validation failures therefore leave all final LM
# menu, action, and generated-config artifacts untouched.
LMSTUDIO_MENU_FILE="$staged_menu" \
LMSTUDIO_MENU_ACTIONS_FILE="$staged_actions" \
    "$GENERATOR"

python3 - \
    "$TEMPLATE_CONFIG_FILE" \
    "$staged_config" \
    "$staged_menu" \
    "$staged_actions" \
    "$MENU_FILE" <<'PY'
import json
import re
import sys
from pathlib import Path
from xml.etree import ElementTree

(
    template_config_file,
    staged_config_file,
    staged_menu_file,
    staged_actions_file,
    final_menu_file,
) = map(Path, sys.argv[1:])

config_lines = template_config_file.read_text().splitlines(keepends=True)
actions_text = re.sub(r"//.*?$", "", staged_actions_file.read_text(), flags=re.MULTILINE)

try:
    menu_actions = json.loads(actions_text)
except json.JSONDecodeError as exc:
    print(f"Error: Invalid LM Studio menu actions: {exc}", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(menu_actions, dict) or not all(
    isinstance(key, str) and isinstance(value, str)
    for key, value in menu_actions.items()
):
    print("Error: LM Studio menu actions must be a string-to-string object", file=sys.stderr)
    raise SystemExit(1)

try:
    menu_root = ElementTree.parse(staged_menu_file).getroot()
except (OSError, ElementTree.ParseError) as exc:
    print(f"Error: Invalid LM Studio menu XML: {exc}", file=sys.stderr)
    raise SystemExit(1)

menu_items = [
    element
    for element in menu_root.iter("object")
    if element.get("class") == "GtkMenuItem"
]
menu_item_ids = [element.get("id") for element in menu_items]
if len(menu_item_ids) != len(set(menu_item_ids)):
    print("Error: LM Studio menu contains duplicate item IDs", file=sys.stderr)
    raise SystemExit(1)

if menu_actions:
    if set(menu_item_ids) != set(menu_actions):
        print("Error: LM Studio menu item IDs do not match menu actions", file=sys.stderr)
        raise SystemExit(1)
elif menu_item_ids == ["no-models"]:
    sensitive = menu_items[0].find("./property[@name='sensitive']")
    if sensitive is None or (sensitive.text or "").strip().lower() != "false":
        print("Error: Empty LM Studio menu item must be insensitive", file=sys.stderr)
        raise SystemExit(1)
else:
    print("Error: Empty LM Studio actions require the no-models menu item", file=sys.stderr)
    raise SystemExit(1)

in_lmstudio = False
in_menu_actions = False
start_line = -1
end_line = -1
brace_count = 0
indent = ""
menu_file_line = -1

for index, line in enumerate(config_lines):
    if '"custom/lmstudio"' in line and "{" in line:
        in_lmstudio = True
        continue

    if in_lmstudio and '"menu-file"' in line:
        menu_file_line = index

    if in_lmstudio and '"menu-actions"' in line:
        in_menu_actions = True
        start_line = index
        indent_match = re.match(r"^(\s*)", line)
        indent = indent_match.group(1) if indent_match else "        "
        brace_count = line.count("{") - line.count("}")
        if brace_count == 0:
            brace_count = 1
        continue

    if in_menu_actions:
        brace_count += line.count("{") - line.count("}")
        if brace_count <= 0:
            end_line = index
            break

if menu_file_line < 0:
    print("Error: Could not find LM Studio menu-file line", file=sys.stderr)
    raise SystemExit(1)
if start_line < 0 or end_line < 0:
    print("Error: Could not find LM Studio menu-actions section", file=sys.stderr)
    raise SystemExit(1)

menu_indent = re.match(r"^(\s*)", config_lines[menu_file_line]).group(1)
comma = "," if config_lines[menu_file_line].rstrip().endswith(",") else ""
config_lines[menu_file_line] = (
    f'{menu_indent}"menu-file": {json.dumps(str(final_menu_file))}{comma}\n'
)

new_lines = config_lines[:start_line]
new_lines.append(f'{indent}"menu-actions": {{\n')
action_items = list(menu_actions.items())
for index, (key, value) in enumerate(action_items):
    comma = "," if index < len(action_items) - 1 else ""
    new_lines.append(f"{indent}    {json.dumps(key)}: {json.dumps(value)}{comma}\n")
new_lines.append(f"{indent}}}\n")
new_lines.extend(config_lines[end_line + 1 :])

rendered_config = "".join(new_lines)
try:
    json.loads(rendered_config)
except json.JSONDecodeError as exc:
    print(f"Error: Generated Waybar config is invalid: {exc}", file=sys.stderr)
    raise SystemExit(1)

staged_config_file.write_text(rendered_config)
PY

# Commit the already validated set. Each replace is same-filesystem and atomic;
# no final artifact is touched before every staged artifact passes validation.
mv -f "$staged_menu" "$MENU_FILE"
staged_menu=""
mv -f "$staged_actions" "$MENU_ACTIONS_FILE"
staged_actions=""
mv -f "$staged_config" "$GENERATED_CONFIG_FILE"
staged_config=""

printf 'Generated Waybar config: %s\n' "$GENERATED_CONFIG_FILE"
if [[ -n "$TEMP_HWMON_PATH" ]]; then
    printf 'Temperature sensor cache: %s\n' "$TEMP_HWMON_PATH"
else
    printf '%s\n' 'Warning: no CPU temperature path found; custom/temperature may show N/A' >&2
fi
