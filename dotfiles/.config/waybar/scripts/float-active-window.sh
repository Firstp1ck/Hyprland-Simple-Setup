#!/usr/bin/env bash
set -euo pipefail

selector=${1:-activewindow}
width=${2:-70%}
height=${3:-55%}

percent_to_pixels() {
  local value=$1
  local total=$2

  if [[ $value == *% ]]; then
    awk -v pct="${value%%%}" -v total="$total" 'BEGIN { printf "%d", total * pct / 100 }'
  else
    printf '%s' "$value"
  fi
}

if [[ "$selector" != "activewindow" ]]; then
  hyprctl dispatch "hl.dsp.focus({ window = \"$selector\" })" >/dev/null
fi

monitor_json=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true)')
monitor_width=$(jq -r '.width' <<< "$monitor_json")
monitor_height=$(jq -r '.height' <<< "$monitor_json")
pixel_width=$(percent_to_pixels "$width" "$monitor_width")
pixel_height=$(percent_to_pixels "$height" "$monitor_height")

hyprctl --batch "dispatch hl.dsp.window.float({ action = \"set\" }); dispatch hl.dsp.window.resize({ x = $pixel_width, y = $pixel_height }); dispatch hl.dsp.window.center()"
