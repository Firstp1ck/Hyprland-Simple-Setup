#!/usr/bin/env bash

STATE_FILE="/tmp/waybar_toggle_state"

# Define the visible and hidden config paths.
VISIBLE_CONFIG="$HOME/.config/waybar/config.jsonc"
HIDDEN_CONFIG="$HOME/.config/waybar/hidden_config.jsonc"

if [ -f "$STATE_FILE" ]; then
    # Currently hidden, switch to visible
    rm "$STATE_FILE"
    pkill -f "waybar -c $HIDDEN_CONFIG"
    # Refresh LM Studio menu before showing waybar (run synchronously to ensure config is updated)
    if [ -f "$HOME/.config/waybar/scripts/lmstudio_refresh_menu.sh" ]; then
        "$HOME/.config/waybar/scripts/lmstudio_refresh_menu.sh" > /dev/null 2>&1
    fi
    waybar -c "$VISIBLE_CONFIG" &
else
    # Currently visible, switch to hidden
    touch "$STATE_FILE"
    pkill -f "waybar -c $VISIBLE_CONFIG"
    waybar -c "$HIDDEN_CONFIG" &
fi