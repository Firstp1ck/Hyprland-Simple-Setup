#!/usr/bin/env bash

# Run the update command
timeout 10s bash -lc 'waybar-module-pacman-updates --no-zero-output'

# Send SIGUSR2 to all waybar processes to trigger a refresh
killall -SIGUSR2 waybar

# Send a notification using dunst
notify-send "Waybar Updates" "Pacman updates refreshed and Waybar reloaded"