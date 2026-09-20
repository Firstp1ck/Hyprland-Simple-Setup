#!/usr/bin/env bash
set -uo pipefail

initial_delay=${HSS_STARTUP_INITIAL_DELAY_SECONDS:-1}
timeout_seconds=${HSS_STARTUP_TIMEOUT_SECONDS:-30}
poll_seconds=${HSS_STARTUP_POLL_SECONDS:-1}
roles_file=${HSS_ROLES_FILE:-$HOME/.config/hypr/roles.json}
script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
startup_state=${HSS_STARTUP_STATE_HELPER:-$script_dir/startup_state.sh}
triage=${HSS_TRIAGE_HELPER:-$HOME/.local/scripts/troubleshoot_with_agent.sh}
app_logs=${XDG_STATE_HOME:-$HOME/.local/state}/hyprland-simple-setup/apps
uid=$(id -u)

sleep "$initial_delay"

notify_failure() {
    local title=$1 body=$2 log=${3:-}
    local args=(
        --source "${BASH_SOURCE[0]}"
        --title "$title"
        --body "$body"
        --urgency critical
        --app-name "Hyprland Simple Setup"
        --icon dialog-warning
    )
    [[ -z $log ]] || args+=(--log "$log")
    if [[ -x $triage ]] && "$triage" "${args[@]}"; then
        return 0
    fi
    notify-send --urgency=critical --app-name="Hyprland Simple Setup" --icon=dialog-warning -- "$title" "$body"
}

process_running() {
    local process=$1
    [[ $process =~ ^[A-Za-z0-9._+-]+$ ]] || return 1
    pgrep -u "$uid" -f "(^|/)$process([[:space:]]|$)" >/dev/null 2>&1
}

marker_ready() {
    "$startup_state" has "$1" >/dev/null 2>&1
}

declare -a process_names=(hyprpaper hypridle wl-clip-persist wl-clipboard-history)
declare -a process_logs=(
    "${XDG_STATE_HOME:-$HOME/.local/state}/hyprland-simple-setup/hyprpaper.log"
    ""
    ""
    ""
)
declare -A process_seen=(
    [hyprpaper]=1
    [hypridle]=1
    [wl-clip-persist]=1
    [wl-clipboard-history]=1
)
roles_valid=true
if [[ -r $roles_file ]]; then
    if jq -e '.roles | type == "object"' "$roles_file" >/dev/null 2>&1; then
        while IFS=$'\t' read -r executable role; do
            [[ -n $executable ]] || continue
            process=${executable##*/}
            [[ -z ${process_seen[$process]+x} ]] || continue
            process_seen[$process]=1
            process_names+=("$process")
            case "$role" in
                bar|dock) process_logs+=("$app_logs/$role.log") ;;
                *) process_logs+=("") ;;
            esac
        done < <(jq -r '
            ["notifications", "bar", "dock"][] as $role
            | .roles[$role]?
            | select(type == "object")
            | [(.executable // ""), $role]
            | @tsv
        ' "$roles_file")
    else
        roles_valid=false
    fi
else
    roles_valid=false
fi

marker_names=(numlock wallpaper)
marker_messages=(
    "Numlock setting was not applied in this Hyprland session."
    "Wallpaper change did not complete in this Hyprland session."
)
expect_dolphin=${HSS_EXPECT_DOLPHIN_FIX:-}
if [[ -z $expect_dolphin ]]; then
    expect_dolphin=0
    autostart_lua=${HSS_AUTOSTART_LUA:-$HOME/.config/hypr/sources/autostart.lua}
    autostart_conf=${HSS_AUTOSTART_CONF:-$HOME/.config/hypr/sources/autostart.conf}
    dolphin_conf_pattern='^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*\$hyprscripts/fix-dolphin[.]sh([[:space:]]*&)?[[:space:]]*$'
    if grep -Fqx '    hl.exec_cmd(apps.hyprscripts .. "/fix-dolphin.sh")' "$autostart_lua" 2>/dev/null \
        || grep -Eq "$dolphin_conf_pattern" "$autostart_conf" 2>/dev/null; then
        expect_dolphin=1
    fi
fi
if [[ $expect_dolphin == 1 ]]; then
    marker_names+=(dolphin)
    marker_messages+=("Dolphin setup did not run in this Hyprland session.")
fi

deadline=$((SECONDS + timeout_seconds))
declare -a missing_markers=() missing_processes=()
while :; do
    missing_markers=()
    missing_processes=()
    for index in "${!marker_names[@]}"; do
        marker_ready "${marker_names[$index]}" || missing_markers+=("$index")
    done
    for index in "${!process_names[@]}"; do
        process_running "${process_names[$index]}" || missing_processes+=("$index")
    done
    ((${#missing_markers[@]} == 0 && ${#missing_processes[@]} == 0)) && break
    ((SECONDS >= deadline)) && break
    sleep "$poll_seconds"
done

failed=0
if [[ $roles_valid != true ]]; then
    notify_failure "Autostart Warning" "Selected application role data is missing or invalid: $roles_file"
    failed=$((failed + 1))
fi
for index in "${missing_markers[@]}"; do
    notify_failure "Autostart Warning" "${marker_messages[$index]}"
    failed=$((failed + 1))
done
for index in "${missing_processes[@]}"; do
    process=${process_names[$index]}
    log=${process_logs[$index]}
    body="Expected current-user process '$process' is not running."
    [[ -z $log ]] || body+=" Diagnostic log: $log"
    notify_failure "Autostart Warning" "$body" "$log"
    failed=$((failed + 1))
done

if ((failed > 0)); then
    notify_failure "Autostart Status" "$failed startup checks failed. No automatic recovery was attempted."
    exit 1
fi
notify-send --urgency=normal --app-name="Hyprland Simple Setup" -- "Autostart Status" "All expected startup components are ready."
