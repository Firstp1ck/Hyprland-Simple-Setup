#!/usr/bin/env bash
set -euo pipefail

roles_file=${HSS_ROLES_FILE:-$HOME/.config/hypr/roles.json}
weather_url='https://www.meteoschweiz.admin.ch/lokalprognose/muri-ag/5630.html#forecast-tab=weekly-overview'

[[ -r $roles_file ]] || {
  printf 'Missing role data: %s\n' "$roles_file" >&2
  exit 1
}
browser=$(jq -er '.roles.browser.executable' "$roles_file")
mapfile -t browser_args < <(jq -r '.roles.browser.args[]?' "$roles_file")
exec "$browser" "${browser_args[@]}" "$weather_url"
