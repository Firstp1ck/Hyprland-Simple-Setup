#!/usr/bin/env bash

# Change wallpaper script for hyprpaper
# This script randomly selects a wallpaper from a configured directory and applies it to all monitors.
# It starts hyprpaper when needed and retries transient IPC connection failures.
# Compatible with hyprpaper 0.8.0+ (uses IPC format: 'monitor, path, fit_mode')

# Load the system-specific Lua data file without executing arbitrary code.
CONFIG_FILE="${HOME}/.config/hypr/sources_specific/change_wallpaper.lua"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found: $CONFIG_FILE"
    exit 1
fi

WALLPAPER_DIR=$(sed -nE 's/^[[:space:]]*wallpaper_dir[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' "$CONFIG_FILE" | head -n1)
WALLPAPER_DIR="${WALLPAPER_DIR/\$HOME/$HOME}"
mapfile -t MONITORS < <(
    sed -nE 's/^[[:space:]]*monitors[[:space:]]*=[[:space:]]*\{(.*)\}.*/\1/p' "$CONFIG_FILE" \
        | grep -oE '"[^"]+"' \
        | tr -d '"'
)

if [ -z "$WALLPAPER_DIR" ]; then
    echo "Invalid wallpaper_dir in $CONFIG_FILE" >&2
    exit 1
fi

WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.jpeg" \) 2>/dev/null | shuf -n 1)
if [ -z "$WALLPAPER" ]; then
  echo "Error: No wallpaper found in $WALLPAPER_DIR" >&2
  exit 1
fi

# Always assign the documented empty-monitor fallback first. Explicit monitor
# assignments follow it so connected outputs receive their requested target.
WALLPAPER_TARGETS=("" "${MONITORS[@]}")
if [ ${#MONITORS[@]} -eq 0 ]; then
  echo "No explicit monitors configured; using the hyprpaper fallback target."
fi

# Recover the active Hyprland environment for manual invocations.
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

hyprpaper_is_running() {
  pgrep -u "$(id -u)" -x hyprpaper >/dev/null 2>&1
}

ensure_hyprpaper_running() {
  local attempt=0
  local max_attempts=30

  ensure_hyprland_env

  if ! hyprctl monitors >/dev/null 2>&1; then
    echo "Error: hyprctl cannot connect (missing/incorrect Hyprland session environment)" >&2
    return 1
  fi

  if ! hyprpaper_is_running; then
    echo "hyprpaper is not running; starting it through Hyprland..." >&2
    hypr_dispatch_exec "hyprpaper" || return 1
  fi

  while [ "$attempt" -lt "$max_attempts" ]; do
    hyprpaper_is_running && return 0
    sleep 0.2
    attempt=$((attempt + 1))
  done

  echo "Error: hyprpaper did not remain running after startup" >&2
  return 1
}

if ! ensure_hyprpaper_running; then
  exit 1
fi

# A real wallpaper request is the IPC readiness check. Retry connection errors
# while hyprpaper creates its socket; do not rely on a particular parser error.
wallpaper_failures=0
for monitor in "${WALLPAPER_TARGETS[@]}"; do
  retry_count=0
  max_retries=30
  success=false
  wallpaper_out=""

  while [ "$retry_count" -lt "$max_retries" ]; do
    wallpaper_out="$(timeout 3 hyprctl hyprpaper wallpaper "$monitor, $WALLPAPER, cover" 2>&1)"
    wallpaper_status=$?
    if [ "$wallpaper_status" -eq 0 ]; then
      success=true
      break
    fi

    retry_count=$((retry_count + 1))
    if ! printf '%s' "$wallpaper_out" | grep -qiE "failed to connect|connection refused|not ready|timed out"; then
      break
    fi
    sleep 0.2
  done

  if [ "$success" = false ]; then
    monitor_label=${monitor:-"the fallback target"}
    echo "Error: Failed to set wallpaper on $monitor_label" >&2
    [ -n "$wallpaper_out" ] && echo "hyprpaper output: $wallpaper_out" >&2
    wallpaper_failures=$((wallpaper_failures + 1))
  fi
done

if [ "$wallpaper_failures" -gt 0 ]; then
  exit 1
fi

# hyprpaper no longer exposes its active wallpaper, so publish the selected
# image for consumers such as wlogout through one atomic cache link.
wlogout_cache_dir="$HOME/.cache/wlogout"
wlogout_background="$wlogout_cache_dir/current-wallpaper"
wlogout_temporary_link="$wlogout_cache_dir/.current-wallpaper.$$"
if mkdir -p -- "$wlogout_cache_dir" \
  && ln -s -- "$WALLPAPER" "$wlogout_temporary_link" \
  && mv -Tf -- "$wlogout_temporary_link" "$wlogout_background"; then
  :
else
  rm -f -- "$wlogout_temporary_link"
  echo "Warning: Could not update the wlogout wallpaper cache." >&2
fi

CURRENT_WALL="$WALLPAPER"

# Create timestamp file for autostart checks
touch "${WALLPAPER_CHANGE_STAMP:-/tmp/wallpaper-change-ran}"

echo "Current wallpaper: $CURRENT_WALL"
echo "New wallpaper: $WALLPAPER"