#!/usr/bin/env bash
set -euo pipefail

exec "${HOME}/.config/waybar/scripts/launch_qt_gui.sh" \
    '^org\.kde\.plasma-systemmonitor$' \
    80% 75% \
    "System Monitor" \
    -- plasma-systemmonitor
