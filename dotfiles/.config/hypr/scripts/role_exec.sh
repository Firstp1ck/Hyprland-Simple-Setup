#!/usr/bin/env bash
set -euo pipefail

roles_file=${HSS_ROLES_FILE:-$HOME/.config/hypr/roles.json}
role=${1:-}
[[ $role =~ ^[a-z][a-z0-9_]*$ ]] || {
  printf 'Usage: role_exec.sh ROLE [--] [args...]\n' >&2
  exit 2
}
shift
[[ ${1:-} != -- ]] || shift
[[ -r $roles_file ]] || { printf 'Missing role data: %s\n' "$roles_file" >&2; exit 1; }

option=$(jq -ce --arg role "$role" '.roles[$role]' "$roles_file") || {
  if [[ $role == gui_editor ]]; then
    role=tui_editor
    option=$(jq -ce '.roles.tui_editor' "$roles_file")
  elif [[ $role == dock ]]; then
    exit 0
  else
    printf 'Role %s is unavailable\n' "$role" >&2
    exit 1
  fi
}

executable=$(jq -er '.executable' <<<"$option")
mapfile -t args < <(jq -r '.args[]?' <<<"$option")
if [[ $(jq -r '.terminal // false' <<<"$option") == true ]]; then
  exec "$HOME/.config/hypr/scripts/term_exec.sh" \
    --app-id "hss-$role" --title "${role//_/ }" -- \
    "$executable" "${args[@]}" "$@"
fi
exec "$executable" "${args[@]}" "$@"
