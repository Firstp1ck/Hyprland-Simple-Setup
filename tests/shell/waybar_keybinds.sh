#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
python3 -B "$repo_root/dotfiles/.config/waybar/tests/test_keybinds_menu_contract.py"
python3 -B "$repo_root/dotfiles/.config/waybar/tests/test_keybinds_parser.py"
