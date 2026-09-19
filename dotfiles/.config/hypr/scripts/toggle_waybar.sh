#!/usr/bin/env bash
set -euo pipefail

roles_file=${HSS_ROLES_FILE:-$HOME/.config/hypr/roles.json}
[[ -r $roles_file ]] || { printf 'Missing role data: %s\n' "$roles_file" >&2; exit 1; }
process=$(jq -er '.roles.bar.executable' "$roles_file")

match=(-x "$process")
signal=()
if [[ $(jq -r '.roles.bar.package' "$roles_file") == nwg-panel ]]; then
  # One nwg-panel process owns both surfaces; its RT signal hides only the bar.
  match=(-f '(^|/|[[:space:]])nwg-panel[[:space:]]+-c[[:space:]]+hss-panels([[:space:]]|$)')
  signal=(--signal RTMIN)
fi
if pgrep -u "$UID" "${match[@]}" >/dev/null 2>&1; then
  pkill -u "$UID" "${signal[@]}" "${match[@]}"
else
  exec "$HOME/.config/hypr/scripts/role_exec.sh" bar
fi
