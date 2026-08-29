#!/usr/bin/env bash
set -euo pipefail

# Merkuro uses Kirigami and does not consume qt6ct's dark custom palette.
# Use KDE's platform theme for this app so it reads the existing dark kdeglobals.
export QT_QPA_PLATFORMTHEME=kde

exec "${HOME}/.config/waybar/scripts/launch_qt_gui.sh" \
    '^org\.kde\.merkuro\.calendar$' \
    80% 80% \
    "Merkuro Calendar" \
    -- merkuro-calendar
