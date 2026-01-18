#!/usr/bin/env bash

# 1. Launch Alacritty with a unique class and track its PID
alacritty --class alacritty-clipboard -t Clipboard -e sh -c 'wl-clipboard-history -l 376 | fzf --bind "ctrl-alt-y:execute-silent(echo {} | sed -E \"s/.*,(.*)/\1/\" | wl-copy)+abort"' &
alacritty_pid=$!

# 2. Wait for window creation using Hyprland's IPC
timeout=5  # max wait in seconds
window_found=false

for ((i=0; i<timeout*10; i++)); do
    # Check for window with matching class and PID
    if hyprctl clients -j | jq -e ".[] | select(.class == \"alacritty-clipboard\" and .pid == $alacritty_pid)" >/dev/null; then
        window_found=true
        break
    fi
    sleep 0.1
done

# 3. Float the window if found
if $window_found; then
    # Focus and float using hyprctl commands
    hyprctl dispatch focuswindow "pid:$alacritty_pid"
    ~/.config/hypr/scripts/toggle_floating.sh
else
    echo "Error: Alacritty clipboard window not detected within $timeout seconds"
fi