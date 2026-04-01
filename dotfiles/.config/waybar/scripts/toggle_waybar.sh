#!/usr/bin/env bash

set -euo pipefail

if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    RUNTIME_DIR="$XDG_RUNTIME_DIR"
    STATE_FILE="$RUNTIME_DIR/waybar_toggle_state"
    PID_FILE="$RUNTIME_DIR/waybar_toggle_pid"
else
    RUNTIME_DIR="/tmp"
    STATE_FILE="$RUNTIME_DIR/waybar_toggle_state_$UID"
    PID_FILE="$RUNTIME_DIR/waybar_toggle_pid_$UID"
fi

# Define the visible and hidden config paths.
VISIBLE_CONFIG="$HOME/.config/waybar/config.jsonc"
HIDDEN_CONFIG="$HOME/.config/waybar/hidden_config.jsonc"

kill_waybar() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            rm -f "$PID_FILE"
            return 0
        fi
        rm -f "$PID_FILE"
    fi

    pkill -u "$USER" -x waybar 2>/dev/null || true
}

start_waybar() {
    waybar -c "$1" &
    echo $! > "$PID_FILE"
}

if [ -f "$STATE_FILE" ]; then
    # Currently hidden, switch to visible
    rm "$STATE_FILE"
    kill_waybar
    # Refresh LM Studio menu before showing waybar (run synchronously to ensure config is updated)
    if [ -f "$HOME/.config/waybar/scripts/lmstudio_refresh_menu.sh" ]; then
        "$HOME/.config/waybar/scripts/lmstudio_refresh_menu.sh" > /dev/null 2>&1
    fi
    start_waybar "$VISIBLE_CONFIG"
else
    # Currently visible, switch to hidden
    touch "$STATE_FILE"
    kill_waybar
    start_waybar "$HIDDEN_CONFIG"
fi