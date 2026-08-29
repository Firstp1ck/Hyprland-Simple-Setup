#!/usr/bin/env bash
set -euo pipefail

roles_file=${HSS_ROLES_FILE:-$HOME/.config/hypr/roles.json}
mode=normal
case "${1:-}" in
  --dmenu) mode=dmenu; shift ;;
  --toggle) mode=toggle; shift ;;
esac

[[ -r "$roles_file" ]] || { printf 'Missing role data: %s\n' "$roles_file" >&2; exit 1; }
process=$(jq -er '.roles.launcher.process' "$roles_file")

if [[ "$mode" == toggle ]] && pgrep -x "$process" >/dev/null 2>&1; then
  pkill -x "$process"
  exit 0
fi

if [[ "$mode" == dmenu ]]; then
  executable=$(jq -er '.roles.launcher.dmenu_executable' "$roles_file")
  mapfile -t args < <(jq -r '.roles.launcher.dmenu_args[]?' "$roles_file")
else
  executable=$(jq -er '.roles.launcher.executable' "$roles_file")
  mapfile -t args < <(jq -r '.roles.launcher.args[]?' "$roles_file")
fi

exec "$executable" "${args[@]}" "$@"
