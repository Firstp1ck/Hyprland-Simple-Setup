#!/usr/bin/env bash
# Wrapper script for VPN toggle/status from Waybar.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VPN_SCRIPT="$SCRIPT_DIR/toggle_vpn.sh"
ACTION="${1:-toggle}"
LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar/vpn_toggle.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

show_notification() {
    local status_msg="$1"
    local urgency="${2:-normal}"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send "VPN" "$status_msg" --urgency="$urgency" --icon=network-vpn
    fi
}

get_vpn_status() {
    local output=""
    local first_line=""

    if output="$("$VPN_SCRIPT" status 2>/dev/null)"; then
        first_line="${output%%$'\n'*}"
    fi

    if [[ -z "${first_line//[[:space:]]/}" ]]; then
        first_line="VPN status unavailable; check the wg-proton configuration."
    fi

    printf '%s\n' "$first_line"
}

# Status must never require authentication.
if [[ "$ACTION" == "status" ]]; then
    status="$(get_vpn_status)"
    printf '%s\n' "$status"
    show_notification "$status" "normal"
    exit 0
fi

run_with_pkexec() {
    command -v pkexec >/dev/null 2>&1 || return 127
    pkexec "$VPN_SCRIPT" "$ACTION"
}

run_with_gui_sudo() {
    local password output exit_code

    if command -v zenity >/dev/null 2>&1; then
        password=$(zenity --password --title="VPN Toggle" --text="Enter your password to toggle VPN:" 2>/dev/null) || return 125
    elif command -v yad >/dev/null 2>&1; then
        password=$(yad --title="VPN Toggle" --text="Enter your password:" --entry --hide-text --button="OK:0" --button="Cancel:1" 2>/dev/null) || return 125
    else
        return 127
    fi

    if [[ -z "$password" ]]; then
        return 125
    fi

    output=$(printf '%s\n' "$password" | sudo -S "$VPN_SCRIPT" "$ACTION" 2>&1)
    exit_code=$?
    unset password

    printf '%s\n' "$output"
    return "$exit_code"
}

log "Starting VPN action: $ACTION"

output=""
exit_code=1

# Prefer polkit for Waybar: it is designed for GUI privilege prompts.
if output=$(run_with_pkexec 2>&1); then
    exit_code=0
else
    exit_code=$?
    log "pkexec failed with $exit_code: $output"

    # Fallback for systems without a working polkit prompt.
    if output=$(run_with_gui_sudo 2>&1); then
        exit_code=0
    else
        exit_code=$?
        log "gui sudo failed with $exit_code: $output"
    fi
fi

if [[ "$exit_code" -eq 0 ]]; then
    sleep 1
    status=$(get_vpn_status)
    log "VPN action succeeded: $status"
    if grep -qi "UP" <<< "$status"; then
        show_notification "VPN Connected: $status" "normal"
    else
        show_notification "VPN Disconnected" "normal"
    fi
    exit 0
fi

log "VPN action failed: $output"
printf 'Error: VPN toggle failed\n%s\n' "$output" >&2
show_notification "VPN toggle failed — see $LOG_FILE" "critical"
exit "$exit_code"
