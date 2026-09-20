#!/usr/bin/env python3
"""Static contract test for the Waybar keybind viewer."""

from __future__ import annotations

import json
import re
import stat
from pathlib import Path
from xml.etree import ElementTree

WAYBAR_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EXPECTED_ACTION = "$HOME/.config/waybar/scripts/keybinds.py"
REQUIRED_PACKAGES = {"python", "tk", "xorg-xwayland"}


def load_jsonc(path: Path) -> dict[str, object]:
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"^\s*//.*$", "", text, flags=re.MULTILINE)
    return json.loads(text)


def main() -> None:
    menu = ElementTree.parse(WAYBAR_DIR / "options_menu.xml")
    menu_ids = {
        item.attrib["id"]
        for item in menu.findall(".//object[@class='GtkMenuItem']")
    }
    assert "keybinds" in menu_ids, menu_ids

    config = load_jsonc(WAYBAR_DIR / "config.jsonc")
    menu_module = config["custom/menu"]
    assert isinstance(menu_module, dict)
    actions = menu_module["menu-actions"]
    assert isinstance(actions, dict)
    assert actions["keybinds"] == EXPECTED_ACTION, actions["keybinds"]

    viewer = WAYBAR_DIR / "scripts/keybinds.py"
    assert viewer.is_file(), viewer
    assert viewer.stat().st_mode & stat.S_IXUSR, f"not executable: {viewer}"
    viewer_text = viewer.read_text(encoding="utf-8")
    assert "~/.config/hypr/sources/keybindings.lua" in viewer_text

    registry = json.loads((REPO_ROOT / "packages.json").read_text(encoding="utf-8"))
    required = set(registry["required"]["pacman"])
    assert REQUIRED_PACKAGES <= required, REQUIRED_PACKAGES - required

    categorized = {
        package
        for packages in registry["hyprland_packages"].values()
        for package in packages
    }
    assert REQUIRED_PACKAGES <= categorized, REQUIRED_PACKAGES - categorized

    print("Waybar keybind viewer contract: OK")


if __name__ == "__main__":
    main()
