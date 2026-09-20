#!/usr/bin/env bash

# Start Weather in a new terminal
# alacritty -t Weather -e bash -c "curl wttr.in/Muri_AG; echo; read -p 'Press enter to close...'" &
kitty -t Weather -e bash -c "curl wttr.in/Muri_AG; echo; read -p 'Press enter to close...'" &

# Wait for the window to appear
sleep 0.2

# Set window properties
hyprctl --batch "dispatch togglefloating; dispatch resizeactive exact 1401 1066; dispatch moveactive exact 512 75"