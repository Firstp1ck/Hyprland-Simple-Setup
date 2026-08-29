#!/usr/bin/env bash
set -euo pipefail

roles_file=${HSS_ROLES_FILE:-$HOME/.config/hypr/roles.json}
title=""
app_id=""

usage() {
  cat <<'EOF'
Usage:
  term_exec.sh [--app-id APP_ID] [--title TITLE] -- <command> [args...]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-id)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      app_id=$2
      shift 2
      ;;
    --title)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      title=$2
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *) break ;;
  esac
done

[[ $# -gt 0 ]] || { usage >&2; exit 2; }
[[ -r "$roles_file" ]] || { printf 'Missing role data: %s\n' "$roles_file" >&2; exit 1; }
[[ -z "$app_id" || "$app_id" =~ ^[A-Za-z0-9._+-]+$ ]] || { printf 'Invalid app ID\n' >&2; exit 2; }

package=$(jq -er '.roles.terminal.package' "$roles_file")
terminal=$(jq -er '.roles.terminal.executable' "$roles_file")
mapfile -t terminal_args < <(jq -r '.roles.terminal.args[]?' "$roles_file")

case "$package" in
  kitty)
    [[ -z "$app_id" ]] || terminal_args+=(--class "$app_id")
    [[ -z "$title" ]] || terminal_args+=(--title "$title")
    exec "$terminal" "${terminal_args[@]}" -e "$@"
    ;;
  alacritty)
    [[ -z "$app_id" ]] || terminal_args+=(--class "$app_id")
    [[ -z "$title" ]] || terminal_args+=(--title "$title")
    exec "$terminal" "${terminal_args[@]}" -e "$@"
    ;;
  ghostty)
    [[ -z "$app_id" ]] || terminal_args+=("--class=$app_id")
    [[ -z "$title" ]] || terminal_args+=("--title=$title")
    exec "$terminal" "${terminal_args[@]}" -e "$@"
    ;;
  *)
    printf 'Unsupported terminal role package: %s\n' "$package" >&2
    exit 1
    ;;
esac
