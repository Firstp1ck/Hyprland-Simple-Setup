#!/usr/bin/env bash
set -euo pipefail

"$HOME/.config/hypr/scripts/term_exec.sh" --app-id hss-clipboard --title Clipboard -- \
  sh -c 'wl-clipboard-history -l 376 | fzf --bind "ctrl-alt-y:execute-silent(echo {} | sed -E \"s/.*,(.*)/\\1/\" | wl-copy)+abort"' &
terminal_pid=$!

window_found=false
for ((i = 0; i < 50; i++)); do
  if hyprctl clients -j | jq -e --argjson pid "$terminal_pid" '.[] | select(.class == "hss-clipboard" and .pid == $pid)' >/dev/null; then
    window_found=true
    break
  fi
  sleep 0.1
done

if $window_found; then
  hyprctl dispatch focuswindow "pid:$terminal_pid"
  "$HOME/.config/hypr/scripts/toggle_floating.sh"
else
  printf 'Clipboard terminal was not detected within 5 seconds\n' >&2
  exit 1
fi
