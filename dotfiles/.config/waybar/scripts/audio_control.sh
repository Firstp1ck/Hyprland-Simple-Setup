#!/usr/bin/env bash
set -euo pipefail

exec "${HOME}/.config/waybar/scripts/launch_qt_gui.sh" \
    '^pavucontrol-qt$' \
    72% 72% \
    "Volume Control" \
    -- pavucontrol-qt
