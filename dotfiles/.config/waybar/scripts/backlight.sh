#!/usr/bin/env bash
# Set a screen backlight to an absolute or relative percentage.

set -euo pipefail

readonly BACKLIGHT_ROOT="${WAYBAR_BACKLIGHT_ROOT:-/sys/class/backlight}"
readonly REQUEST="${1:-}"

notify_error() {
    local message="$1"

    printf 'backlight.sh: %s\n' "$message" >&2
    if command -v notify-send >/dev/null 2>&1; then
        notify-send --urgency=critical "Waybar brightness" "$message" || true
    fi
}

select_backlight_path() {
    local requested_device="${WAYBAR_BACKLIGHT_DEVICE:-}"
    local path candidate_max
    local best_path=""
    local best_max=-1

    if [[ -n "$requested_device" ]]; then
        if [[ ! "$requested_device" =~ ^[A-Za-z0-9._:-]+$ ]]; then
            return 1
        fi
        path="$BACKLIGHT_ROOT/$requested_device"
        if [[ -d "$path" && -r "$path/brightness" && -r "$path/max_brightness" ]]; then
            printf '%s\n' "$path"
            return 0
        fi
        return 1
    fi

    # Match Waybar 0.15.0 BacklightBackend::best_device(): select the usable
    # device with the greatest max_brightness, retaining the first on a tie.
    shopt -s nullglob
    for path in "$BACKLIGHT_ROOT"/*; do
        [[ -d "$path" && -r "$path/brightness" && -r "$path/max_brightness" ]] || continue
        candidate_max="$(<"$path/max_brightness")"
        [[ "$candidate_max" =~ ^[0-9]+$ ]] || continue
        if ((candidate_max > best_max)); then
            best_path="$path"
            best_max=$candidate_max
        fi
    done
    shopt -u nullglob

    [[ -n "$best_path" ]] || return 1
    printf '%s\n' "$best_path"
}

if [[ ! "$REQUEST" =~ ^[+-]?([0-9]|[1-9][0-9]|100)$ ]]; then
    notify_error "Use an absolute percentage from 0 to 100, or a relative value such as +10 or -10."
    exit 2
fi

if ! backlight_path="$(select_backlight_path)"; then
    if [[ -n "${WAYBAR_BACKLIGHT_DEVICE:-}" ]]; then
        notify_error "Backlight device '${WAYBAR_BACKLIGHT_DEVICE}' is unavailable."
    else
        notify_error "No usable screen backlight device was found."
    fi
    exit 1
fi

brightness_file="$backlight_path/brightness"
max_brightness="$(<"$backlight_path/max_brightness")"
current_brightness="$(<"$brightness_file")"
device_name="$(basename "$backlight_path")"

if [[ ! "$max_brightness" =~ ^[0-9]+$ || ! "$current_brightness" =~ ^[0-9]+$ ]] || ((max_brightness <= 0)); then
    notify_error "Backlight device '$device_name' returned invalid brightness values."
    exit 1
fi

if [[ "$REQUEST" == [+-]* ]]; then
    percent="${REQUEST:1}"
    delta=$((percent * max_brightness / 100))
    if [[ "$REQUEST" == -* ]]; then
        new_brightness=$((current_brightness - delta))
    else
        new_brightness=$((current_brightness + delta))
    fi
else
    new_brightness=$((REQUEST * max_brightness / 100))
fi

if ((new_brightness < 0)); then
    new_brightness=0
elif ((new_brightness > max_brightness)); then
    new_brightness=$max_brightness
fi

if [[ -w "$brightness_file" ]]; then
    if ! printf '%s\n' "$new_brightness" >"$brightness_file"; then
        notify_error "Could not set brightness on '$device_name'."
        exit 1
    fi
elif [[ "$BACKLIGHT_ROOT" != "/sys/class/backlight" ]]; then
    notify_error "The selected backlight test path is not writable."
    exit 1
elif command -v pkexec >/dev/null 2>&1; then
    if ! printf '%s\n' "$new_brightness" | pkexec tee "$brightness_file" >/dev/null; then
        notify_error "Authorization was cancelled or brightness could not be changed on '$device_name'."
        exit 1
    fi
else
    notify_error "Permission is required to change '$device_name', and pkexec is unavailable."
    exit 1
fi
