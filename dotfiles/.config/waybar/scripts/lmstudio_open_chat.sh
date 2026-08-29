#!/usr/bin/env bash
# Script to open LM Studio GUI

set -euo pipefail

# Check if lmstudio GUI is available
LMSTUDIO_CMD=""
if command -v lmstudio &> /dev/null; then
    LMSTUDIO_CMD="lmstudio"
elif [ -f "/usr/sbin/lmstudio" ]; then
    LMSTUDIO_CMD="/usr/sbin/lmstudio"
else
    notify-send -u critical "LM Studio" "Error: LM Studio GUI not found"
    exit 1
fi

# Launch LM Studio GUI
"$LMSTUDIO_CMD" &

exit 0

