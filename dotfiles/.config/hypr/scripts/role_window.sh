#!/usr/bin/env bash
set -euo pipefail

role=${1:-}
case "$role" in
  calendar|audio) ;;
  *) printf 'Usage: role_window.sh calendar|audio [args...]\n' >&2; exit 2 ;;
esac
shift
roles_file=${HSS_ROLES_FILE:-$HOME/.config/hypr/roles.json}
package=$(jq -er --arg role "$role" '.roles[$role].package' "$roles_file")
if [[ $(jq -r --arg role "$role" '.roles[$role].terminal // false' "$roles_file") == true ]]; then
  exec "$HOME/.config/hypr/scripts/role_exec.sh" "$role" "$@"
fi
case "$role:$package" in
  calendar:merkuro) class='^org\.kde\.merkuro\.calendar$' ;;
  calendar:gnome-calendar) class='^org\.gnome\.Calendar$' ;;
  calendar:korganizer) class='^(org\.kde\.)?korganizer$' ;;
  audio:pavucontrol) class='^(org\.pulseaudio\.)?pavucontrol$' ;;
  audio:pavucontrol-qt) class='^pavucontrol-qt$' ;;
  audio:qastools) class='^qasmixer$' ;;
  *) printf 'Unsupported window role: %s:%s\n' "$role" "$package" >&2; exit 1 ;;
esac
executable=$(jq -er --arg role "$role" '.roles[$role].executable' "$roles_file")
mapfile -t args < <(jq -r --arg role "$role" '.roles[$role].args[]?' "$roles_file")
exec "$HOME/.config/waybar/scripts/launch_qt_gui.sh" \
  "$class" '70%' '70%' "$role" -- "$executable" "${args[@]}" "$@"
