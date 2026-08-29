#!/usr/bin/env bash
# Waybar JSON: CPU temperature with per-sensor / per-core tooltip.

set -euo pipefail

readonly CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar"
readonly CACHE_PATH="${CACHE_DIR}/temperature_hwmon_path"
readonly RESOLVER="${HOME}/.config/waybar/scripts/temperature_resolve_path.sh"
readonly CRITICAL_C=80
readonly ICONS=($'\uf72b' $'\uf2c9' $'\uf769')

primary_sensor_path() {
    local path=""
    if [[ -s "$CACHE_PATH" ]]; then
        path="$(cat "$CACHE_PATH")"
    else
        path="$("$RESOLVER" 2>/dev/null || true)"
    fi
    [[ -n "$path" && -r "$path" ]] || return 1
    readlink -f "$path"
}

read_millicelsius() {
    local path="$1"
    local raw
    raw="$(cat "$path" 2>/dev/null)" || return 1
    [[ "$raw" =~ ^[0-9]+$ ]] || return 1
    if (( raw < 1000 || raw > 150000 )); then
        return 1
    fi
    echo $((raw / 1000))
}

sensor_label() {
    local input_path="$1"
    local label_path="${input_path/_input/_label}"
    local label=""
    if [[ -r "$label_path" ]]; then
        label="$(cat "$label_path" 2>/dev/null)" || true
    fi
    if [[ -z "$label" ]]; then
        label="$(basename "$input_path" _input)"
    fi
    printf '%s' "$label"
}

pick_icon() {
    local temp="$1"
    if (( temp >= CRITICAL_C )); then
        printf '%s' "${ICONS[2]}"
    elif (( temp >= 55 )); then
        printf '%s' "${ICONS[1]}"
    else
        printf '%s' "${ICONS[0]}"
    fi
}

# Prints "label|celsius" lines sorted for display.
collect_hwmon_readings() {
    local hwmon_dir="$1"
    local f input_path label temp
    local -a lines=()

    shopt -s nullglob
    for f in "$hwmon_dir"/temp*_input; do
        temp="$(read_millicelsius "$f")" || continue
        label="$(sensor_label "$f")"
        idx="${f##*/temp}"
        idx="${idx%_input}"
        lines+=("$(printf '%03d|%s|%s' "$idx" "$label" "$temp")")
    done
    shopt -u nullglob

    if ((${#lines[@]} == 0)); then
        return 1
    fi

    printf '%s\n' "${lines[@]}" | sort -t'|' -k1,1n | cut -d'|' -f2-
}

collect_thermal_zone_readings() {
    local zone_path="$1"
    local temp ztype
    temp="$(read_millicelsius "$zone_path")" || return 1
    ztype="$(cat "$(dirname "$zone_path")/type" 2>/dev/null)" || ztype="thermal"
    printf '%s|%s\n' "$ztype" "$temp"
}

# Prefer sensors -j labels when available (coretemp "Core 0", etc.).
collect_sensors_json_readings() {
    local chip="$1"
    local adapter_key
    if ! command -v sensors >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        return 1
    fi

    adapter_key="$(sensors -j 2>/dev/null | jq -r --arg chip "$chip" '
        to_entries[]
        | select(.key | test($chip; "i"))
        | .key
        ' | head -n1)"

    [[ -n "$adapter_key" && "$adapter_key" != "null" ]] || return 1

    sensors -j 2>/dev/null | jq -r --arg key "$adapter_key" '
        .[$key]
        | to_entries[]
        | select(.value | type == "object")
        | .key as $label
        | ([.value | to_entries[] | select(.key | test("^temp[0-9]+_input$")) | .value] | first) as $c
        | select($c != null and $c >= 1 and $c <= 150)
        | "\($label)|\($c | floor)"
    ' 2>/dev/null
}

main() {
    local primary dir chip tooltip_lines="" label temp icon css_class=""
    local -a tooltip_parts=()

    if ! primary="$(primary_sensor_path)"; then
        jq -cn '{text: "󰈸 N/A", tooltip: "No CPU temperature sensor found\nLeft click: open System Monitor", class: "unavailable"}'
        exit 0
    fi

    if [[ "$primary" == */thermal_zone* ]]; then
        while IFS='|' read -r label temp; do
            [[ -n "$label" ]] || continue
            tooltip_parts+=("$(printf '%s: %s°C' "$label" "$temp")")
        done < <(collect_thermal_zone_readings "$primary" || true)
        temp="$(read_millicelsius "$primary")" || temp=0
    else
        dir="$(dirname "$primary")"
        chip="$(cat "${dir}/name" 2>/dev/null)" || chip="cpu"

        if ! tooltip_lines="$(collect_sensors_json_readings "$chip")"; then
            tooltip_lines="$(collect_hwmon_readings "$dir")"
        fi

        while IFS='|' read -r label temp; do
            [[ -n "$label" ]] || continue
            tooltip_parts+=("$(printf '%s: %s°C' "$label" "$temp")")
        done <<<"$tooltip_lines"

        temp="$(read_millicelsius "$primary")" || temp="${temp:-0}"
    fi

    if ((${#tooltip_parts[@]} == 0)); then
        tooltip_parts+=("Temperature: ${temp}°C")
    fi

    icon="$(pick_icon "$temp")"
    if (( temp >= CRITICAL_C )); then
        css_class="critical"
        tooltip_parts+=("Critical temperature: ${temp}°C")
    fi
    tooltip_parts+=("Left click: open System Monitor")

    local text
    text="$(printf '%s %s°C %s' $'\uf2db' "$temp" "$icon")"

    jq -cn \
        --arg text "$text" \
        --arg tooltip "$(printf '%s\n' "${tooltip_parts[@]}")" \
        --arg class "$css_class" \
        '{text: $text, tooltip: $tooltip, class: $class}'
}

main
