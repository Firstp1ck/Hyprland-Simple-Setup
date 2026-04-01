#!/usr/bin/env bash

# Change wallpaper script for hyprpaper
# This script randomly selects a wallpaper from a configured directory and applies it to all monitors.
# It handles hyprpaper's hanging IPC commands by running them in background and cleaning up afterwards.
# Compatible with hyprpaper 0.8.0+ (uses new IPC format: 'monitor, path, fit_mode')

# shellcheck disable=SC1090

# Load system-specific configuration file
CONFIG_FILE="${HOME}/.config/hypr/sources_specific/change_wallpaper.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Config file not found: $CONFIG_FILE"
    exit 1
fi

# Ensure hyprpaper is running and IPC is working
# In hyprpaper 0.8.0, we need to test IPC connectivity, not just process existence
ensure_hyprland_env() {
  local uid runtime_dir hypr_dir sig wayland_sock

  uid="$(id -u)"
  runtime_dir="${XDG_RUNTIME_DIR:-/run/user/${uid}}"
  export XDG_RUNTIME_DIR="$runtime_dir"

  if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    for hypr_dir in "$runtime_dir"/hypr/*; do
      if [ -d "$hypr_dir" ]; then
        sig="${hypr_dir##*/}"
        if [ -S "$hypr_dir/.socket2.sock" ] || [ -S "$hypr_dir/.socket.sock" ]; then
          export HYPRLAND_INSTANCE_SIGNATURE="$sig"
          break
        fi
      fi
    done
  fi

  if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    for wayland_sock in "$runtime_dir"/wayland-*; do
      if [ -S "$wayland_sock" ]; then
        export WAYLAND_DISPLAY="${wayland_sock##*/}"
        break
      fi
    done
  fi
}

hypr_dispatch_exec() {
  # Start a process *inside* the active Hyprland session.
  # This avoids launching wlroots clients without the right logind/seat context.
  hyprctl dispatch exec "$1" >/dev/null 2>&1
}

ensure_hyprpaper_ready() {
  local max_attempts=30
  local attempt=0
  
  ensure_hyprland_env

  # If we can't talk to Hyprland at all, don't try to launch hyprpaper.
  if ! hyprctl monitors >/dev/null 2>&1; then
    echo "Error: hyprctl cannot connect (missing/incorrect Hyprland session environment)" >&2
    return 1
  fi

  # Ensure hyprpaper is running (start it via Hyprland, not directly).
  if ! pgrep -x hyprpaper >/dev/null 2>&1; then
    hypr_dispatch_exec "hyprpaper"
    sleep 0.5
  fi
  
  # Test IPC connectivity by trying a wallpaper command (with invalid args to test connection)
  # If IPC isn't working, restart hyprpaper
  while [ $attempt -lt $max_attempts ]; do
    if pgrep -x hyprpaper >/dev/null 2>&1; then
      # Test if IPC is working by checking if hyprctl can connect
      # Using an invalid command to test connectivity (will return "not enough args" if connected)
      local ipc_test_out
      ipc_test_out="$(hyprctl hyprpaper wallpaper 2>&1 || true)"

      if printf '%s' "$ipc_test_out" | grep -q "not enough args"; then
        # IPC is working (got "not enough args" error, which means connection succeeded)
        return 0
      elif printf '%s' "$ipc_test_out" | grep -q "failed to connect"; then
        # IPC not working, restart hyprpaper (again: via Hyprland)
        pkill -x hyprpaper 2>/dev/null
        sleep 0.3
        hypr_dispatch_exec "hyprpaper"
        sleep 0.5
      else
        # Give it more time to initialize
        sleep 0.2
      fi
    else
      # Process not running, start it (via Hyprland)
      hypr_dispatch_exec "hyprpaper"
      sleep 0.5
    fi
    attempt=$((attempt + 1))
  done
  return 1
}

if ! ensure_hyprpaper_ready; then
  echo "Error: hyprpaper IPC not ready after 6 seconds" >&2
  exit 1
fi

# Get a random wallpaper
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.jpeg" \) 2>/dev/null | shuf -n 1)

# Check if we found a wallpaper
if [ -z "$WALLPAPER" ]; then
  echo "Error: No wallpaper found in $WALLPAPER_DIR" >&2
  exit 1
fi

# Check if monitors array is set
if [ ${#MONITORS[@]} -eq 0 ]; then
  echo "Error: MONITORS array is empty" >&2
  exit 1
fi

# Clean up any old hanging processes from previous runs
pkill -f "hyprctl.*hyprpaper" 2>/dev/null
sleep 0.1

# Set wallpaper on each monitor with retry logic
# New hyprpaper 0.8.0 IPC format: 'monitor, path, fit_mode'
# fit_mode is optional and defaults to 'cover' if omitted
for monitor in "${MONITORS[@]}"; do
  retry_count=0
  max_retries=3
  success=false
  
  while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
    # New format requires spaces: monitor, path, fit_mode
    if hyprctl hyprpaper wallpaper "$monitor, $WALLPAPER, cover" &>/dev/null; then
      success=true
    else
      retry_count=$((retry_count + 1))
      if [ $retry_count -lt $max_retries ]; then
        sleep 0.1
      fi
    fi
  done
  
  if [ "$success" = false ]; then
    echo "Error: Failed to set wallpaper on $monitor after $max_retries attempts" >&2
  fi
done

# Note: listactive command was removed in hyprpaper 0.8.0
# We can't retrieve current wallpaper via IPC anymore
CURRENT_WALL="(unavailable - listactive removed in hyprpaper 0.8.0)"

# Create timestamp file for autostart checks
touch /tmp/wallpaper-change-ran

echo "Current wallpaper: $CURRENT_WALL"
echo "New wallpaper: $WALLPAPER"