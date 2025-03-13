#!/usr/bin/env bash

WALLPAPER_DIR="ADD FOLDER PATH"  # Replace with your wallpaper directory

MONITORS=("DP-1" "DP-2")  # Replace with your actual monitor names (use `hyprctl monitors`)

# Ensure hyprpaper is running
if ! hyprctl clients | grep -q hyprpaper; then
  hyprpaper &
  sleep 0.5 # Allow socket initialization
fi

# Get current wallpaper (if any)
CURRENT_WALL=$(hyprctl hyprpaper listloaded | grep -oP 'image: \K.*' | head -1)

# Get a random wallpaper excluding the current one
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" \) ! -name "$(basename "$CURRENT_WALL")" | shuf -n 1)

# Apply wallpaper to all monitors
hyprctl hyprpaper preload "$WALLPAPER"
for monitor in "${MONITORS[@]}"; do
  hyprctl hyprpaper wallpaper "$monitor,$WALLPAPER"
done

echo "Current wallpaper: $CURRENT_WALL"
echo "New wallpaper: $WALLPAPER"
