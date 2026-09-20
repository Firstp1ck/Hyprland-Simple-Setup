#!/usr/bin/env bash
set -euo pipefail

roles_file=${HSS_ROLES_FILE:-$HOME/.config/hypr/roles.json}
[[ -r $roles_file ]] || { printf 'Missing role data: %s\n' "$roles_file" >&2; exit 1; }
provider=$(jq -er '.roles.notifications.package' "$roles_file")

if [[ $provider == swaync ]]; then
  exec swaync-client -swb
fi

while true; do
  jq -cn --arg provider "$provider" '{
    text: "",
    class: $provider,
    tooltip: ("Notifications: " + $provider + "\nLeft click: notification action • Right click: do not disturb")
  }'
  sleep 5
done
