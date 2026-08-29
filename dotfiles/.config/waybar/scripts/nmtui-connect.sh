#!/usr/bin/env bash
set -euo pipefail

exec "${HOME}/.config/waybar/scripts/launch_qt_gui.sh" \
    '^org\.kde\.plasmawindowed$' \
    42% 65% \
    "Network picker" \
    -- plasmawindowed org.kde.plasma.networkmanagement
