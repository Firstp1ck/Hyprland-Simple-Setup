#!/usr/bin/env bash
# Report LM Studio model status as one-line Waybar JSON.

set -euo pipefail

if [[ -d "$HOME/.lmstudio/bin" ]]; then
    export PATH="$PATH:$HOME/.lmstudio/bin"
fi

emit_status() {
    local text="$1"
    local tooltip="$2"

    jq -cn --arg text "$text" --arg tooltip "$tooltip" '{text: $text, tooltip: $tooltip}'
}

if command -v lms >/dev/null 2>&1; then
    LMS_CMD="lms"
elif [[ -x "$HOME/.lmstudio/bin/lms" ]]; then
    LMS_CMD="$HOME/.lmstudio/bin/lms"
else
    emit_status "󰚩 N/A" $'LM Studio\nCLI not found\nRight click: choose a model after setup'
    exit 0
fi

if ! curl --fail --silent --max-time 2 http://127.0.0.1:1234/health >/dev/null 2>&1; then
    emit_status "󰚩 Offline" $'LM Studio\nServer is offline\nRight click: choose a model and start it'
    exit 0
fi

loaded_model="$("$LMS_CMD" ps 2>/dev/null | awk 'NF && $1 != "IDENTIFIER" { print $1; exit }' || true)"

if [[ -z "$loaded_model" ]]; then
    emit_status "󰚩 No Model" $'LM Studio\nNo model loaded\nRight click: choose a model'
else
    short_name="${loaded_model##*/}"
    short_name="${short_name%%-*}"
    short_name="${short_name:0:15}"
    tooltip=$'LM Studio\nModel: '"$loaded_model"$'\nLeft click: eject • Right click: choose model'
    emit_status "󰚩 $short_name" "$tooltip"
fi
