#!/usr/bin/env bash
set -euo pipefail

roles_file=${HSS_ROLES_FILE:-$HOME/.config/hypr/roles.json}
weather_url=${WEATHER_LOCATION_URL:-https://www.meteoschweiz.admin.ch/lokalprognose/zuerich/8001.html#forecast-tab=weekly-overview}
browser=$(jq -er '.roles.browser.executable' "$roles_file")
mapfile -t browser_args < <(jq -r '.roles.browser.args[]?' "$roles_file")
exec "$browser" "${browser_args[@]}" "$weather_url"
