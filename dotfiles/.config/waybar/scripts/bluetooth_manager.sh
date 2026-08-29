#!/usr/bin/env bash
set -euo pipefail

exec "${HOME}/.config/waybar/scripts/launch_qt_gui.sh" \
    '^kcm_bluetooth$' \
    65% 70% \
    "Bluetooth" \
    -- kcmshell6 kcm_bluetooth
