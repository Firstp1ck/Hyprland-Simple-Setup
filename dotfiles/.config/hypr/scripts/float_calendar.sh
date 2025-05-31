#!/bin/bash

# Launch calcurse in kitty
hyprctl dispatch exec "kitty -e calcurse"

# Wait for the window to appear (adjust sleep if needed)
sleep 0.2

# Run the toggle floating script (it will float and resize the active window)
~/.config/hypr/scripts/toggle_floating.sh