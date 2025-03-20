#!/usr/bin/env bash

STATE_FILE="/tmp/waybar_toggle_state"

# Define the visible and hidden config paths.
VISIBLE_CONFIG="$HOME/.config/waybar/config.jsonc"
HIDDEN_CONFIG="$HOME/.config/waybar/hidden_config.jsonc"

if [ -f "$STATE_FILE" ]; then
    # Currently hidden, switch to visible
    rm "$STATE_FILE"
    pkill -f "waybar -c $HIDDEN_CONFIG"
    waybar -c "$VISIBLE_CONFIG" &
else
    # Currently visible, switch to hidden
    touch "$STATE_FILE"
    pkill -f "waybar -c $VISIBLE_CONFIG"
    waybar -c "$HIDDEN_CONFIG" &
fi