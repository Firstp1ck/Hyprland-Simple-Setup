#!/usr/bin/env bash
# Script to change LM Studio model

set -euo pipefail

MODEL_NAME="${1:?Usage: lmstudio_change_model.sh <model-key>}"
SERVER_URL="http://127.0.0.1:1234"

# Add LM Studio bin to PATH if not already present
if [ -d "$HOME/.lmstudio/bin" ]; then
    export PATH="$PATH:$HOME/.lmstudio/bin"
fi

# Check if the LM Studio CLI exists.
LMS_CMD=""
if command -v lms &> /dev/null; then
    LMS_CMD="lms"
elif [ -x "$HOME/.lmstudio/bin/lms" ]; then
    LMS_CMD="$HOME/.lmstudio/bin/lms"
else
    notify-send -u critical \
        "LM Studio CLI unavailable" \
        "The 'lms' command was not found. Install or repair LM Studio/llmster."
    exit 1
fi

server_is_ready() {
    curl --fail --silent --max-time 2 "$SERVER_URL/health" >/dev/null 2>&1
}

# Start llmster and the server on demand, then wait up to 20 seconds for health.
if ! server_is_ready; then
    notify-send -u normal "LM Studio" "Server is offline. Starting llmster..."

    DAEMON_START_OUTPUT=""
    if ! DAEMON_START_OUTPUT=$(timeout 30s "$LMS_CMD" daemon up 2>&1); then
        ERROR_SUMMARY=${DAEMON_START_OUTPUT%%$'\n'*}
        ERROR_MESSAGE="Cannot start llmster. Install or repair the LM Studio headless daemon."
        if [ -n "$ERROR_SUMMARY" ]; then
            ERROR_MESSAGE+=$'\n\n'"$ERROR_SUMMARY"
        fi
        notify-send -u critical "LM Studio daemon unavailable" "$ERROR_MESSAGE"
        exit 1
    fi

    notify-send -u normal "LM Studio" "Starting local server..."
    SERVER_START_OUTPUT=""
    if ! SERVER_START_OUTPUT=$(timeout 15s "$LMS_CMD" server start --cors --port 1234 2>&1); then
        ERROR_SUMMARY=${SERVER_START_OUTPUT%%$'\n'*}
        ERROR_MESSAGE="llmster is running, but the local server could not start."
        if [ -n "$ERROR_SUMMARY" ]; then
            ERROR_MESSAGE+=$'\n\n'"$ERROR_SUMMARY"
        fi
        notify-send -u critical "LM Studio server unavailable" "$ERROR_MESSAGE"
        exit 1
    fi

    for _ in {1..40}; do
        server_is_ready && break
        sleep 0.5
    done

    if ! server_is_ready; then
        notify-send -u critical \
            "LM Studio server unavailable" \
            "The backend started but port 1234 did not become healthy within 20 seconds."
        exit 1
    fi
fi

# Avoid unloading and reloading the requested model when it is already active.
CURRENT_MODEL=$("$LMS_CMD" ps 2>/dev/null | awk 'NR > 1 && NF { print $1; exit }' || true)
if [ "$CURRENT_MODEL" = "$MODEL_NAME" ]; then
    notify-send -u normal "LM Studio" "Model already loaded: $MODEL_NAME"
    exit 0
fi

# Unload the current model before loading the requested one.
if [ -n "$CURRENT_MODEL" ]; then
    "$LMS_CMD" unload "$CURRENT_MODEL" 2>/dev/null || true
    sleep 2
fi

# Load new model using LM Studio defaults/app presets
# (do not force --gpu/--context-length here)
notify-send -u normal "LM Studio" "Loading model: $MODEL_NAME"
if "$LMS_CMD" load "$MODEL_NAME" -y; then
    notify-send -u normal "LM Studio" "Model loaded: $MODEL_NAME"
else
    notify-send -u critical "LM Studio" "Failed to load model: $MODEL_NAME"
    exit 1
fi

exit 0

