#!/usr/bin/env bash
# Dispatch non-update maintenance actions from the Waybar update menu.

set -euo pipefail

readonly ACTION="${1:-}"
readonly DETAILED_LOG_FILE="${WAYBAR_UPDATE_LOG_FILE:-${HOME}/Linux-Setup-detailed.log}"

error() {
    printf 'Error: %s\n' "$*" >&2
}

require_command() {
    local command_name=$1

    if ! command -v "$command_name" >/dev/null 2>&1; then
        error "Required command '${command_name}' was not found."
        return 127
    fi
}

pause_if_interactive() {
    if [[ -t 0 && -t 1 ]]; then
        printf '\nPress Enter to close this terminal...'
        read -r _ || true
    fi
}

run_check() {
    local output=""
    local status=0

    require_command checkupdates || return $?

    printf 'Official repository updates:\n'
    if output=$(checkupdates 2>&1); then
        if [[ -n "$output" ]]; then
            printf '%s\n' "$output"
        else
            printf 'No official repository updates are available.\n'
        fi
    else
        status=$?
        if ((status == 2)); then
            printf 'No official repository updates are available.\n'
        else
            error "checkupdates failed with exit status ${status}."
            [[ -z "$output" ]] || printf '%s\n' "$output" >&2
            return "$status"
        fi
    fi

    printf '\nAUR updates:\n'
    if ! command -v yay >/dev/null 2>&1; then
        printf "The optional AUR helper 'yay' is not installed; skipping the AUR check.\n"
        return 0
    fi

    if output=$(yay -Qua 2>&1); then
        if [[ -n "$output" ]]; then
            printf '%s\n' "$output"
        else
            printf 'No AUR updates are available.\n'
        fi
    else
        status=$?
        error "yay -Qua failed with exit status ${status}."
        [[ -z "$output" ]] || printf '%s\n' "$output" >&2
        return "$status"
    fi
}

run_firmware() {
    local output=""
    local status=0

    require_command fwupdmgr || return $?
    require_command sudo || return $?

    printf 'Refreshing firmware metadata...\n'
    if sudo fwupdmgr refresh --force; then
        :
    else
        status=$?
        error "fwupdmgr refresh failed with exit status ${status}."
        return "$status"
    fi

    printf '\nChecking for firmware updates...\n'
    if output=$(LC_ALL=C fwupdmgr get-updates 2>&1); then
        [[ -z "$output" ]] || printf '%s\n' "$output"
    else
        status=$?
        error "fwupdmgr get-updates failed with exit status ${status}."
        [[ -z "$output" ]] || printf '%s\n' "$output" >&2
        return "$status"
    fi

    if [[ "$output" != *'Updates available'* ]]; then
        printf 'No firmware updates are available.\n'
        return 0
    fi

    printf '\nInstalling firmware updates...\n'
    if sudo fwupdmgr update -y; then
        :
    else
        status=$?
        error "fwupdmgr update failed with exit status ${status}."
        return "$status"
    fi
}

run_review_pacnew() {
    require_command pacdiff || return $?
    require_command sudo || return $?

    printf 'Starting interactive .pacnew review with pacdiff...\n'
    sudo pacdiff
}

run_clean_cache() {
    require_command paccache || return $?
    require_command sudo || return $?

    printf 'Removing old package cache versions with paccache...\n'
    sudo paccache -r
}

run_show_log() {
    local latest_session_line=""
    local line=""
    local line_number=0

    require_command less || return $?
    if [[ ! -f "$DETAILED_LOG_FILE" || ! -r "$DETAILED_LOG_FILE" ]]; then
        error "The detailed update log is missing or unreadable: ${DETAILED_LOG_FILE}"
        return 66
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_number += 1))
        if [[ "$line" == *'[SESSION_START]'* ]]; then
            latest_session_line=$line_number
        fi
    done < "$DETAILED_LOG_FILE"

    if [[ -n "$latest_session_line" ]]; then
        LESSSECURE=1 less "+${latest_session_line}g" -- "$DETAILED_LOG_FILE"
    else
        LESSSECURE=1 less -- "$DETAILED_LOG_FILE"
    fi
}

if (($# != 1)); then
    error 'Exactly one action is required: check, firmware, review-pacnew, clean-cache, or show-log.'
    pause_if_interactive
    exit 2
fi

status=0
case "$ACTION" in
    check)
        run_check || status=$?
        ;;
    firmware)
        run_firmware || status=$?
        ;;
    review-pacnew)
        run_review_pacnew || status=$?
        ;;
    clean-cache)
        run_clean_cache || status=$?
        ;;
    show-log)
        run_show_log || status=$?
        ;;
    *)
        error "Unknown maintenance action: ${ACTION}"
        status=2
        ;;
esac

pause_if_interactive
exit "$status"
