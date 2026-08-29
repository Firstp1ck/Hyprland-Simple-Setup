#!/usr/bin/env bash
# Unload the currently active LM Studio model from the Waybar module.

set -euo pipefail

if [ -d "$HOME/.lmstudio/bin" ]; then
    export PATH="$PATH:$HOME/.lmstudio/bin"
fi

LMS_CMD=""
if command -v lms >/dev/null 2>&1; then
    LMS_CMD="lms"
elif [ -x "$HOME/.lmstudio/bin/lms" ]; then
    LMS_CMD="$HOME/.lmstudio/bin/lms"
else
    notify-send -u critical \
        "LM Studio CLI unavailable" \
        "The 'lms' command was not found. Install or repair LM Studio/llmster."
    exit 1
fi

PS_OUTPUT=""
if ! PS_OUTPUT=$("$LMS_CMD" ps 2>/dev/null); then
    notify-send -u critical \
        "LM Studio" \
        "Could not determine the currently loaded model."
    exit 1
fi

CURRENT_MODEL=$(awk 'NF && $1 != "IDENTIFIER" { print $1; exit }' <<< "$PS_OUTPUT")
if [ -z "$CURRENT_MODEL" ]; then
    notify-send -u normal "LM Studio" "No model is currently loaded."
    exit 0
fi

if "$LMS_CMD" unload "$CURRENT_MODEL"; then
    notify-send -u normal "LM Studio" "Model ejected: $CURRENT_MODEL"
else
    notify-send -u critical "LM Studio" "Failed to eject model: $CURRENT_MODEL"
    exit 1
fi
