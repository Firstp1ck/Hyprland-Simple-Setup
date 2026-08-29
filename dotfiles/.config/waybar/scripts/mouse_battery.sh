#!/usr/bin/env bash
# Report an OpenRazer battery without changing package, group, or service state.

set -u

notify_error() {
    local message="$1"
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/waybar"
    local state_file="$cache_dir/mouse_battery_error"

    mkdir -p "$cache_dir" 2>/dev/null || true

    # Waybar polls this script; notify only when the error message changes.
    if [[ -r "$state_file" ]] && [[ "$(<"$state_file")" == "$message" ]]; then
        printf '%s\n' "$message" >&2
        return
    fi
    printf '%s' "$message" >"$state_file" 2>/dev/null || true

    if command -v notify-send >/dev/null 2>&1; then
        notify-send --urgency=critical "Waybar mouse battery" "$message" || true
    else
        printf '%s\n' "$message" >&2
    fi
}

clear_error_state() {
    rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/waybar/mouse_battery_error" 2>/dev/null || true
}

missing_tools=()
for tool in razer-cli awk grep; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        missing_tools+=("$tool")
    fi
done

if ((${#missing_tools[@]} > 0)); then
    notify_error "Missing required tool(s): ${missing_tools[*]}. Install openrazer-meta and the standard text utilities, then restart Waybar."
    printf '%s\n' "󰂑 N/A"
    exit 0
fi

get_razer_battery_device() {
    razer-cli -ls 2>/dev/null | awk '
        /^[^[:space:]].*:$/ {
            device=$0
            sub(/:$/, "", device)
            next
        }
        /^[[:space:]]+battery:/ && device != "" {
            print device
            exit
        }
    '
}

get_battery_info() {
    local device
    device="$(get_razer_battery_device)"

    if [[ -n "$device" ]]; then
        razer-cli -d "$device" --battery print 2>&1
    else
        razer-cli --battery print 2>&1
    fi
}

battery_info=""
if battery_info="$(get_battery_info)"; then
    razer_status=0
else
    razer_status=$?
fi

if ((razer_status != 0)); then
    if printf '%s\n' "$battery_info" | grep -qi 'Found 0 Razer device'; then
        clear_error_state
        printf '%s\n' "󰂑 N/A"
        exit 0
    fi

    current_user="${USER:-$(id -un)}"
    if ! id -nG "$current_user" | grep -qw openrazer; then
        notify_error "OpenRazer access is not configured. Run 'sudo gpasswd -a $current_user openrazer', then log out and back in."
    else
        notify_error "Could not connect to OpenRazer. Check it with 'systemctl --user status openrazer-daemon.service'."
    fi

    printf '%s\n' "󰂑 N/A"
    exit 0
fi

charge="$(printf '%s\n' "$battery_info" | awk -F': *' '{ key=$1; gsub(/^[[:space:]]+|[[:space:]]+$/, "", key); if (tolower(key) ~ /^(charge|battery)$/) {print $2; exit} }' | grep -oE '^[0-9]+' || true)"
charging="$(printf '%s\n' "$battery_info" | awk -F': *' '{ key=$1; gsub(/^[[:space:]]+|[[:space:]]+$/, "", key); if (tolower(key) == "charging") {print $2; exit} }')"

if [[ ! "$charge" =~ ^[0-9]+$ ]] || ((charge > 100)); then
    if [[ -z "${battery_info//[[:space:]]/}" ]] || printf '%s\n' "$battery_info" | grep -qi 'Found 0 Razer device'; then
        clear_error_state
        printf '%s\n' "󰂑 N/A"
        exit 0
    fi

    notify_error "Could not read a valid mouse battery charge. razer-cli output: ${battery_info//$'\n'/ }"
    printf '%s\n' "󰂑 N/A"
    exit 0
fi

clear_error_state

if ((charge >= 80)); then
    icon=""
elif ((charge >= 60)); then
    icon=""
elif ((charge >= 40)); then
    icon=""
elif ((charge >= 20)); then
    icon=""
else
    icon=""
fi

if [[ "${charging,,}" == "true" ]]; then
    charging_icon=" "
else
    charging_icon=""
fi

printf '%s %s%%%s\n' "$icon" "$charge" "$charging_icon"
