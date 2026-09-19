#!/usr/bin/env bash
set -euo pipefail

roles_file=${HSS_ROLES_FILE:-$HOME/.config/hypr/roles.json}
[[ -r $roles_file ]] || { printf 'Missing role data: %s\n' "$roles_file" >&2; exit 1; }
process=$(jq -er '.roles.bar.executable' "$roles_file")

match=(-x "$process")
if [[ $(jq -r '.roles.bar.package' "$roles_file") == nwg-panel ]]; then
  # The dock uses the same executable with a different named profile.
  match=(-f '(^|/|[[:space:]])nwg-panel[[:space:]]+-c[[:space:]]+bar([[:space:]]|$)')
fi
if pgrep -u "$USER" "${match[@]}" >/dev/null 2>&1; then
  pkill -u "$USER" "${match[@]}"
else
  exec "$HOME/.config/hypr/scripts/role_exec.sh" bar
fi
