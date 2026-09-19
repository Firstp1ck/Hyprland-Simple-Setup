#!/usr/bin/env bash
set -euo pipefail

role=${1:-}
case "$role" in bar|dock) shift ;; *) printf 'Usage: nwg_panel.sh bar|dock [args...]\n' >&2; exit 2 ;; esac
roles_file=${HSS_ROLES_FILE:-$HOME/.config/hypr/roles.json}
selected=$(jq -er --arg role "$role" '.roles[$role].package' "$roles_file")
[[ $selected == nwg-panel ]] || { printf 'nwg-panel is not selected for %s\n' "$role" >&2; exit 2; }
bar=$(jq -r '.roles.bar.package // ""' "$roles_file")
dock=$(jq -r '.roles.dock.package // ""' "$roles_file")

# Upstream nwg-panel replaces existing instances. One process must own both panels.
if [[ $role == dock && $bar == nwg-panel ]]; then
    exit 0
fi
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nwg-panel"
profiles=("$config_dir/$role")
if [[ $role == bar && $dock == nwg-panel ]]; then
    profiles+=("$config_dir/dock")
fi
for profile in "${profiles[@]}"; do
    [[ -r $profile ]] || { printf 'Missing nwg-panel profile: %s\n' "$profile" >&2; exit 1; }
done
signal=$(kill -l RTMIN)
tmp=$(mktemp "$config_dir/.hss-panels.XXXXXX")
trap 'rm -f -- "$tmp"' EXIT
jq -s --argjson signal "$signal" '
    add | map(
        .["use-sigrt"] = (.name == "bar")
        | if .name == "bar" then .sigrt = $signal else . end
    )
' "${profiles[@]}" > "$tmp"
mv -f -- "$tmp" "$config_dir/hss-panels"
trap - EXIT
exec nwg-panel -c hss-panels "$@"
