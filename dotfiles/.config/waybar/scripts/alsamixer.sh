#!/usr/bin/env bash
set -euo pipefail

exec "${HOME}/.config/waybar/scripts/launch_qt_gui.sh" \
    '^qasmixer$' \
    65% 70% \
    "QasMixer" \
    -- qasmixer
