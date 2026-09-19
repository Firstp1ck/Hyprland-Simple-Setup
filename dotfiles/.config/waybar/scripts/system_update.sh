#!/usr/bin/env bash
# Repository-owned backend for the Waybar full-update actions.
set -euo pipefail

readonly LOG_FILE="${WAYBAR_UPDATE_LOG_FILE:-${XDG_STATE_HOME:-${HOME}/.local/state}/hyprland-simple-setup/system-update.log}"

pause_if_interactive() {
    if [[ -t 0 && -t 1 ]]; then
        printf '\nPress Enter to close this terminal...'
        read -r _ || true
    fi
}
trap pause_if_interactive EXIT

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf "Error: Required command '%s' was not found.\n" "$1" >&2
        return 127
    fi
}

if (($# != 2)) || [[ $1 != --function ]]; then
    printf 'Usage: system_update.sh --function update_arch|update_arch_without_aur\n' >&2
    exit 2
fi
case "$2" in
    update_arch|update_arch_without_aur) mode=$2 ;;
    *) printf 'Unknown update function: %s\n' "$2" >&2; exit 2 ;;
esac

require_command id
uid=$(id -u)
if [[ $uid == 0 ]]; then
    printf 'Error: Run this updater as your normal desktop user, not as root.\n' >&2
    exit 77
fi
require_command pacman
require_command tee

command=(sudo pacman -Syu)
aur_skipped=false
if [[ $mode == update_arch ]]; then
    if command -v paru >/dev/null 2>&1; then
        command=(paru -Syu)
    elif command -v yay >/dev/null 2>&1; then
        command=(yay -Syu)
    else
        aur_skipped=true
    fi
fi
require_command "${command[0]}"

# Refuse to start a transaction if its log cannot be opened.
umask 077
mkdir -p -- "$(dirname -- "$LOG_FILE")"
printf '\n[SESSION_START] %(%Y-%m-%dT%H:%M:%S%z)T %s\n' -1 "$mode" >> "$LOG_FILE"
{
    printf 'System update: %s\n' "${command[*]}"
    printf 'Review the package-manager prompts; confirmations remain enabled.\n'
    if [[ $aur_skipped == true ]]; then
        printf 'Warning: Neither paru nor yay is installed; AUR updates will be skipped.\n'
    fi
    printf 'Log: %s\n\n' "$LOG_FILE"
} | tee -a -- "$LOG_FILE"

# Keep terminal stdin for prompts; capture both command and logging failures.
set +e
"${command[@]}" 2>&1 | tee -a -- "$LOG_FILE"
statuses=("${PIPESTATUS[@]}")
set -e
status=${statuses[0]}
if ((status == 0 && statuses[1] != 0)); then
    status=${statuses[1]}
fi
if ((status == 0)); then
    if [[ $aur_skipped == true ]]; then
        result='Official repository update completed. AUR updates were skipped because no helper is installed.'
    else
        result='System update completed.'
    fi
else
    result="System update failed with exit status ${status}. No fallback update was attempted."
fi
printf '\n%s\n' "$result"
if ! printf '[SESSION_END] status=%s %s\n' "$status" "$result" >> "$LOG_FILE"; then
    printf 'Error: Could not write the final update status to the log.\n' >&2
    if ((status == 0)); then status=1; fi
fi
exit "$status"
