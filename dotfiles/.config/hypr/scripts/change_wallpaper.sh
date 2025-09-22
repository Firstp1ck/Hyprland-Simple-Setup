#!/usr/bin/env bash

# shellcheck disable=SC1090

# Load system-specific configuration file (prefer runtime config)
CONFIG_FILE_RUNTIME="${HOME}/.config/hypr/sources/change_wallpaper.conf"
CONFIG_FILE_DOTFILES="${HOME}/dotfiles/.config/hypr/sources/change_wallpaper.conf"
if [ -f "$CONFIG_FILE_RUNTIME" ]; then
    CONFIG_FILE="$CONFIG_FILE_RUNTIME"
elif [ -f "$CONFIG_FILE_DOTFILES" ]; then
    CONFIG_FILE="$CONFIG_FILE_DOTFILES"
else
    echo "Config file not found in ~/.config or dotfiles"
    exit 1
fi
source "$CONFIG_FILE"

# Ensure hyprpaper is running
if ! hyprctl clients | grep -q hyprpaper; then
  hyprpaper &
  sleep 1.0 # Allow socket initialization
fi

# Auto-detect monitors if MONITORS is unset, empty, or contains placeholder
if [ -z "${MONITORS+x}" ] || [ ${#MONITORS[@]} -eq 0 ] || printf '%s' "${MONITORS[*]}" | grep -q "^MONITOR$"; then
  readarray -t DETECTED_MONITORS < <(hyprctl monitors | awk '/^Monitor/{print $2}')
  if [ ${#DETECTED_MONITORS[@]} -eq 0 ]; then
    echo "No monitors detected via hyprctl"
    exit 1
  fi
  MONITORS=("${DETECTED_MONITORS[@]}")
  # Persist detected monitors back into the config, preserving other lines
  TMPCFG=$(mktemp)
  if grep -q '^MONITORS=' "$CONFIG_FILE"; then
    awk -v repl="MONITORS=(\"${MONITORS[*]}\")" '{if ($0 ~ /^MONITORS=/) print repl; else print}' "$CONFIG_FILE" > "$TMPCFG"
  else
    cat "$CONFIG_FILE" > "$TMPCFG"
    printf '\nMONITORS=("%s")\n' "${MONITORS[*]}" >> "$TMPCFG"
  fi
  mv "$TMPCFG" "$CONFIG_FILE"
fi

# Get current wallpaper (if any)
CURRENT_WALL=$(hyprctl hyprpaper listloaded | grep -oP 'image: \K.*' | head -1)

# Get a random wallpaper excluding the current one
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.jpeg" \) ! -name "$(basename "$CURRENT_WALL")" | shuf -n 1)

# Apply wallpaper to all monitors
hyprctl hyprpaper preload "$WALLPAPER"
for monitor in "${MONITORS[@]}"; do
  hyprctl hyprpaper wallpaper "$monitor,$WALLPAPER"
done

# Create timestamp file
touch /tmp/wallpaper-change-ran

echo "Current wallpaper: $CURRENT_WALL"
echo "New wallpaper: $WALLPAPER"