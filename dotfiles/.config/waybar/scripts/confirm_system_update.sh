#!/usr/bin/env bash

set -euo pipefail

readonly DIALOG="${WAYBAR_UPDATE_DIALOG:-zenity}"
readonly LAUNCHER="${WAYBAR_UPDATE_LAUNCHER:-${HOME}/.config/waybar/scripts/launch_system_update.sh}"

notify_failure() {
    local message=$1

    printf 'System Update: %s\n' "$message" >&2
    if command -v notify-send >/dev/null 2>&1; then
        notify-send --urgency=critical "Waybar: System Update" "$message" || true
    fi
}

if ! dialog_path=$(command -v "$DIALOG"); then
    notify_failure "The '${DIALOG}' confirmation dialog is unavailable."
    exit 127
fi
if [[ ! -x "$LAUNCHER" ]]; then
    notify_failure "The system-update launcher is missing or not executable: ${LAUNCHER}"
    exit 126
fi

if "$dialog_path" \
    --question \
    --title="System Update" \
    --text="Start the system update now?" \
    --ok-label="Start update" \
    --cancel-label="Cancel"; then
    exec "$LAUNCHER"
else
    status=$?
fi

if ((status == 1)); then
    exit 0
fi

notify_failure "The confirmation dialog failed with exit status ${status}."
exit "$status"
