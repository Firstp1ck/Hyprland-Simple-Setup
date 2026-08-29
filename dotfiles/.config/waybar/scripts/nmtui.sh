#!/usr/bin/env bash
set -euo pipefail

exec "${HOME}/.config/waybar/scripts/launch_qt_gui.sh" \
    '^kcm_networkmanagement$' \
    72% 75% \
    "Network settings" \
    -- kcmshell6 kcm_networkmanagement
