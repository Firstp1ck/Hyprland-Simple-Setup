#!/usr/bin/env bash
set -euo pipefail

roles_file=${HSS_ROLES_FILE:-$HOME/.config/hypr/roles.json}
floating=$(hyprctl activewindow -j | jq -r '.floating')
window=$(hyprctl activewindow -j | jq -r '.initialClass')
terminal_class=$(jq -er '.roles.terminal.class' "$roles_file")

handle() {
  local width=$1 height=$2
  if [[ "$floating" == false ]]; then
    hyprctl --batch "dispatch togglefloating; dispatch resizeactive exact ${width} ${height}; dispatch centerwindow"
  else
    hyprctl dispatch togglefloating
  fi
}

case "$window" in
  "$terminal_class"|hss-scratchpad|hss-clipboard|hss-notes|hss-calendar|hss-keybinds|hss-repos)
    handle "50%" "55%"
    ;;
  *) handle "70%" "70%" ;;
esac
