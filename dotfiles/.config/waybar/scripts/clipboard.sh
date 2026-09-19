#!/usr/bin/env bash
set -euo pipefail

term_exec=${HSS_TERM_EXEC:-$HOME/.config/hypr/scripts/term_exec.sh}
clipboard_command='wl-clipboard-history -l 376 | fzf --bind "ctrl-alt-y:execute-silent(echo {} | sed -E \"s/.*,(.*)/\1/\" | wl-copy)+abort"'

"$term_exec" --app-id hss-clipboard --title Clipboard -- sh -c "$clipboard_command" &
terminal_pid=$!

clipboard_window=""
for ((attempt = 0; attempt < 50; attempt++)); do
  clipboard_window=$(hyprctl clients -j | jq -cer --argjson pid "$terminal_pid" \
    '.[] | select(.class == "hss-clipboard" and .pid == $pid)' || true)
  [[ -z $clipboard_window ]] || break
  sleep 0.1
done

if [[ -z $clipboard_window ]]; then
  printf 'Error: clipboard window not detected within 5 seconds\n' >&2
  exit 1
fi

hyprctl dispatch focuswindow "pid:$terminal_pid"
if [[ $(jq -r '.floating' <<<"$clipboard_window") == false ]]; then
  hyprctl --batch 'dispatch togglefloating; dispatch resizeactive exact 50% 55%; dispatch centerwindow'
else
  hyprctl --batch 'dispatch resizeactive exact 50% 55%; dispatch centerwindow'
fi
