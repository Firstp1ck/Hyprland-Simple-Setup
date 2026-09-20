#!/usr/bin/env bash
set -euo pipefail

roles_file=${HSS_ROLES_FILE:-$HOME/.config/hypr/roles.json}
action=${1:-toggle}
[[ -r $roles_file ]] || { printf 'Missing role data: %s\n' "$roles_file" >&2; exit 1; }
provider=$(jq -er '.roles.notifications.package' "$roles_file")

case "$provider:$action" in
  swaync:toggle) exec swaync-client -t -sw ;;
  swaync:dnd) exec swaync-client -d -sw ;;
  mako:toggle) exec makoctl dismiss --all ;;
  mako:dnd) exec makoctl mode -t do-not-disturb ;;
  dunst:toggle) exec dunstctl history-pop ;;
  dunst:dnd) exec dunstctl set-paused toggle ;;
  fnott:toggle) exec fnottctl dismiss all ;;
  fnott:dnd) exit 0 ;;
  *) printf 'Unsupported notification action: %s for %s\n' "$action" "$provider" >&2; exit 2 ;;
esac
