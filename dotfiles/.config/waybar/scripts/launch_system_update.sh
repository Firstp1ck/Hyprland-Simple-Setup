#!/usr/bin/env bash
# Start the system updater in an independent, duplicate-safe terminal service.

set -euo pipefail

readonly UNIT_NAME="${WAYBAR_UPDATE_UNIT:-waybar-system-update}"
readonly UNIT="${UNIT_NAME%.service}.service"
readonly TERMINAL_LAUNCHER="${WAYBAR_UPDATE_TERMINAL_LAUNCHER:-${HOME}/.config/hypr/scripts/term_exec.sh}"
readonly UPDATE_SCRIPT="${WAYBAR_UPDATE_SCRIPT:-}"
readonly MAINTENANCE_SCRIPT="${WAYBAR_UPDATE_MAINTENANCE_SCRIPT:-${HOME}/.config/waybar/scripts/update_maintenance_action.sh}"
readonly WINDOW_CLASS="${WAYBAR_UPDATE_CLASS:-waybar-system-update}"
readonly WINDOW_TITLE="${WAYBAR_UPDATE_TITLE:-System Update}"
readonly FLOAT_HELPER="${HOME}/.config/waybar/scripts/float-active-window.sh"
readonly UPDATE_MODE="${1-default}"

notify_message() {
    local urgency=$1
    local message=$2

    printf 'System Update: %s\n' "$message" >&2
    if command -v notify-send >/dev/null 2>&1; then
        notify-send --urgency="$urgency" "Waybar: System Update" "$message" || true
    fi
}

unit_state() {
    systemctl --user show "$UNIT" --property=ActiveState --value 2>/dev/null || printf 'inactive\n'
}

is_running_state() {
    case $1 in
        active | activating | reloading)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

hyprland_signature() {
    local signature=""

    signature=$(systemctl --user show-environment 2>/dev/null \
        | awk -F= '$1 == "HYPRLAND_INSTANCE_SIGNATURE" { print $2; exit }')
    if [[ -n "$signature" ]]; then
        printf '%s\n' "$signature"
    else
        printf '%s\n' "${HYPRLAND_INSTANCE_SIGNATURE:-}"
    fi
}

find_window_address() {
    local signature=$1

    [[ -n "$signature" ]] || return 0
    command -v hyprctl >/dev/null 2>&1 || return 0
    command -v jq >/dev/null 2>&1 || return 0

    HYPRLAND_INSTANCE_SIGNATURE="$signature" hyprctl clients -j 2>/dev/null \
        | jq -r --arg class "$WINDOW_CLASS" '
            first(
                .[]
                | select(
                    (.class // "") == $class
                    or (.initialClass // "") == $class
                )
                | .address
            ) // empty
        ' 2>/dev/null
}

focus_window() {
    local signature=$1
    local address=""

    address=$(find_window_address "$signature")
    [[ -n "$address" ]] || return 1

    if [[ -x "$FLOAT_HELPER" ]]; then
        HYPRLAND_INSTANCE_SIGNATURE="$signature" \
            "$FLOAT_HELPER" "address:${address}" "70%" "60%" >/dev/null 2>&1 || true
    elif command -v hyprctl >/dev/null 2>&1; then
        HYPRLAND_INSTANCE_SIGNATURE="$signature" \
            hyprctl dispatch "hl.dsp.focus({ window = \"address:${address}\" })" >/dev/null 2>&1 || true
    fi
    return 0
}

if (($# > 1)); then
    notify_message critical "Too many update mode arguments were provided."
    exit 2
fi

declare -a ACTION_COMMAND
ACTION_SCRIPT_KIND=""
case "$UPDATE_MODE" in
    default)
        if [[ -z "$UPDATE_SCRIPT" ]]; then
            notify_message critical "Set WAYBAR_UPDATE_SCRIPT to enable full system updates."
            exit 78
        fi
        ACTION_SCRIPT_KIND="update"
        ACTION_COMMAND=("$UPDATE_SCRIPT" --function update_arch)
        ;;
    --without-aur)
        if [[ -z "$UPDATE_SCRIPT" ]]; then
            notify_message critical "Set WAYBAR_UPDATE_SCRIPT to enable full system updates."
            exit 78
        fi
        ACTION_SCRIPT_KIND="update"
        ACTION_COMMAND=("$UPDATE_SCRIPT" --function update_arch_without_aur)
        ;;
    --check)
        ACTION_SCRIPT_KIND="maintenance"
        ACTION_COMMAND=("$MAINTENANCE_SCRIPT" check)
        ;;
    --firmware)
        ACTION_SCRIPT_KIND="maintenance"
        ACTION_COMMAND=("$MAINTENANCE_SCRIPT" firmware)
        ;;
    --review-pacnew)
        ACTION_SCRIPT_KIND="maintenance"
        ACTION_COMMAND=("$MAINTENANCE_SCRIPT" review-pacnew)
        ;;
    --clean-cache)
        ACTION_SCRIPT_KIND="maintenance"
        ACTION_COMMAND=("$MAINTENANCE_SCRIPT" clean-cache)
        ;;
    --show-log)
        ACTION_SCRIPT_KIND="maintenance"
        ACTION_COMMAND=("$MAINTENANCE_SCRIPT" show-log)
        ;;
    *)
        notify_message critical "Unknown update mode: ${UPDATE_MODE}"
        exit 2
        ;;
esac
readonly ACTION_SCRIPT_KIND
readonly -a ACTION_COMMAND

if [[ ! "$UNIT_NAME" =~ ^[A-Za-z0-9_.@-]+$ ]]; then
    notify_message critical "The transient service name is invalid."
    exit 2
fi
if ! command -v systemd-run >/dev/null 2>&1 || ! command -v systemctl >/dev/null 2>&1; then
    notify_message critical "systemd user-service tools are unavailable."
    exit 127
fi
if [[ ! -x "$TERMINAL_LAUNCHER" ]]; then
    notify_message critical "The terminal launcher is missing or not executable: ${TERMINAL_LAUNCHER}"
    exit 127
fi
if [[ ! -x "${ACTION_COMMAND[0]}" ]]; then
    notify_message critical "The ${ACTION_SCRIPT_KIND} script is missing or not executable: ${ACTION_COMMAND[0]}"
    exit 126
fi

signature=$(hyprland_signature)
state=$(unit_state)
if is_running_state "$state"; then
    focus_window "$signature" || true
    notify_message normal "The system update is already running."
    exit 0
fi

if ! systemd-run \
    --user \
    --quiet \
    --collect \
    --no-block \
    --unit="$UNIT_NAME" \
    --description="Waybar system update" \
    "$TERMINAL_LAUNCHER" \
    --app-id "$WINDOW_CLASS" \
    --title "$WINDOW_TITLE" \
    -- "${ACTION_COMMAND[@]}"; then
    state=$(unit_state)
    if is_running_state "$state"; then
        focus_window "$signature" || true
        notify_message normal "The system update is already running."
        exit 0
    fi
    notify_message critical "The update terminal could not be started."
    exit 1
fi

# This launcher runs in Waybar's asynchronous action child. Waiting briefly for
# the window does not block Waybar, and lets repeated clicks focus one terminal.
for _ in {1..80}; do
    if focus_window "$signature"; then
        exit 0
    fi

    state=$(unit_state)
    if ! is_running_state "$state"; then
        break
    fi
    sleep 0.1
done

state=$(unit_state)
if is_running_state "$state"; then
    notify_message critical "The update started, but its terminal window could not be detected."
else
    notify_message critical "The update terminal exited before its window became available."
fi
exit 1
