#!/usr/bin/env python3
"""Static contract tests for the Waybar update menu and launcher."""

from __future__ import annotations

import json
import re
from pathlib import Path
from xml.etree import ElementTree

WAYBAR_DIR = Path(__file__).resolve().parents[1]
EXPECTED_IDS = [
    "check",
    "update",
    "update-no-aur",
    "firmware",
    "review-pacnew",
    "clean-cache",
    "show-log",
]
EXPECTED_LEFT_CLICK = "$HOME/.config/waybar/scripts/confirm_system_update.sh"
EXPECTED_ACTIONS = {
    "check": "$HOME/.config/waybar/scripts/launch_system_update.sh --check",
    "update": "$HOME/.config/waybar/scripts/launch_system_update.sh",
    "update-no-aur": "$HOME/.config/waybar/scripts/launch_system_update.sh --without-aur",
    "firmware": "$HOME/.config/waybar/scripts/launch_system_update.sh --firmware",
    "review-pacnew": "$HOME/.config/waybar/scripts/launch_system_update.sh --review-pacnew",
    "clean-cache": "$HOME/.config/waybar/scripts/launch_system_update.sh --clean-cache",
    "show-log": "$HOME/.config/waybar/scripts/launch_system_update.sh --show-log",
}


def load_jsonc(path: Path) -> dict[str, object]:
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"^\s*//.*$", "", text, flags=re.MULTILINE)
    return json.loads(text)


def main() -> None:
    menu = ElementTree.parse(WAYBAR_DIR / "update_menu.xml")
    menu_ids = [
        item.attrib["id"]
        for item in menu.findall(".//object[@class='GtkMenuItem']")
    ]
    assert menu_ids == EXPECTED_IDS, menu_ids
    assert len(menu.findall(".//object[@class='GtkSeparatorMenuItem']")) == 3

    config = load_jsonc(WAYBAR_DIR / "config.jsonc")
    update_module = config["custom/updates"]
    assert isinstance(update_module, dict)
    assert update_module["on-click"] == EXPECTED_LEFT_CLICK
    actions = update_module["menu-actions"]
    assert actions == EXPECTED_ACTIONS, actions
    assert list(actions) == menu_ids

    launcher = (WAYBAR_DIR / "scripts/launch_system_update.sh").read_text(
        encoding="utf-8"
    )
    required_routes = [
        'ACTION_COMMAND=("$UPDATE_SCRIPT" --function update_arch)',
        'ACTION_COMMAND=("$UPDATE_SCRIPT" --function update_arch_without_aur)',
        'ACTION_COMMAND=("$MAINTENANCE_SCRIPT" check)',
        'ACTION_COMMAND=("$MAINTENANCE_SCRIPT" firmware)',
        'ACTION_COMMAND=("$MAINTENANCE_SCRIPT" review-pacnew)',
        'ACTION_COMMAND=("$MAINTENANCE_SCRIPT" clean-cache)',
        'ACTION_COMMAND=("$MAINTENANCE_SCRIPT" show-log)',
        'readonly UNIT_NAME="${WAYBAR_UPDATE_UNIT:-waybar-system-update}"',
        'readonly UPDATE_SCRIPT="${WAYBAR_UPDATE_SCRIPT:-}"',
        '"$TERMINAL_LAUNCHER"',
        '-- "${ACTION_COMMAND[@]}"',
        'Set WAYBAR_UPDATE_SCRIPT to enable full system updates.',
    ]
    for route in required_routes:
        assert route in launcher, route
    assert "eval " not in launcher

    status_wrapper = (
        WAYBAR_DIR / "scripts/updates_status.sh"
    ).read_text(encoding="utf-8")
    for hint in [
        "Left click: start system update",
        "Right click: update options",
    ]:
        assert hint in status_wrapper, hint
    assert '$hint + "\\n\\n" + $current' in status_wrapper

    confirmation = (
        WAYBAR_DIR / "scripts/confirm_system_update.sh"
    ).read_text(encoding="utf-8")
    for required in [
        '--text="Start the system update now?"',
        'exec "$LAUNCHER"',
        "if ((status == 1)); then",
    ]:
        assert required in confirmation, required

    dispatcher = (
        WAYBAR_DIR / "scripts/update_maintenance_action.sh"
    ).read_text(encoding="utf-8")
    for action in ["check", "firmware", "review-pacnew", "clean-cache", "show-log"]:
        assert re.search(rf"^    {re.escape(action)}\)$", dispatcher, re.MULTILINE), action
    for forbidden in ["pacman -Sc", "pacman -Scc", "yay -Sc", "rm -rf"]:
        assert forbidden not in dispatcher, forbidden

    print("Waybar update menu contract: OK")


if __name__ == "__main__":
    main()
