#!/usr/bin/env bash
# Resolve a sysfs path for Waybar's temperature module (CPU-ish sensor).
# Prints one absolute path on stdout; exits 1 if none found.
#
# Typical Arch setups: k10temp/coretemp hwmon, or thermal_zone x86_pkg_temp.

set -euo pipefail

debug() {
    if [[ "${WAYBAR_TEMP_DEBUG:-0}" == 1 ]]; then
        echo "temperature_resolve_path: $*" >&2
    fi
}

readable_temp_file() {
    local path="$1"
    [[ -r "$path" ]] || return 1
    local raw
    raw="$(cat "$path" 2>/dev/null)" || return 1
    [[ "$raw" =~ ^[0-9]+$ ]] || return 1
    # millidegrees C; ignore bogus / disconnected readings
    if (( raw < 1000 || raw > 150000 )); then
        return 1
    fi
    printf '%s\n' "$(readlink -f "$path")"
}

find_hwmon_by_name() {
    local chip="$1"
    local h name
    for h in /sys/class/hwmon/hwmon*/; do
        [[ -d "$h" ]] || continue
        name="$(cat "${h}name" 2>/dev/null)" || continue
        [[ -n "$name" ]] || continue
        [[ "$name" == "$chip" ]] || continue
        if readable_temp_file "${h}temp1_input"; then
            return 0
        fi
        # Some boards expose CPU on temp2 (e.g. asusec)
        if [[ "$chip" == asusec ]] && readable_temp_file "${h}temp2_input"; then
            return 0
        fi
    done
    return 1
}

find_thermal_zone() {
    local z ztype path
    for z in /sys/class/thermal/thermal_zone*/; do
        [[ -d "$z" ]] || continue
        ztype="$(cat "${z}type" 2>/dev/null)" || continue
        case "$ztype" in
            x86_pkg_temp | acpitz | Processor | cpu-thermal | *pkg* | *CPU*)
                path="${z}temp"
                if readable_temp_file "$path"; then
                    return 0
                fi
                ;;
        esac
    done
    if readable_temp_file /sys/class/thermal/thermal_zone0/temp; then
        return 0
    fi
    return 1
}

should_skip_hwmon() {
    local name="$1"
    case "$name" in
        nvme | amdgpu | r8169 | enp* | spd* | jc42 | max31785*)
            return 0
            ;;
    esac
    return 1
}

find_fallback_hwmon() {
    local h name
    for h in /sys/class/hwmon/hwmon*/; do
        [[ -d "$h" ]] || continue
        name="$(cat "${h}name" 2>/dev/null)" || continue
        [[ -n "$name" ]] || continue
        should_skip_hwmon "$name" && continue
        if readable_temp_file "${h}temp1_input"; then
            debug "fallback hwmon: $name"
            return 0
        fi
    done
    return 1
}

main() {
    local chip
    # CPU thermal drivers, most common on Arch first
    local -a preferred_chips=(
        k10temp
        zenpower
        coretemp
        acpitz
        asusec
        nct6779
        nct6799
        it87
        w83627ehf
    )

    for chip in "${preferred_chips[@]}"; do
        if find_hwmon_by_name "$chip"; then
            debug "matched hwmon chip: $chip"
            return 0
        fi
    done

    if find_thermal_zone; then
        debug "matched thermal_zone"
        return 0
    fi

    if find_fallback_hwmon; then
        return 0
    fi

    debug "no temperature sensor path found"
    return 1
}

main
