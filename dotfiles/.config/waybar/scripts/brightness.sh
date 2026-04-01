#!/usr/bin/env bash

# shellcheck disable=SC2086
# Double quote to prevent globbing and word splitting.

# DDC/CI I2C bus selection:
# - By default, this script auto-detects buses via `ddcutil detect` and uses the first two.
# - You can override with env vars: BUS1 and BUS2 (numbers like 8, 9).
# - Avoid privileged kernel/module reloads unless explicitly enabled (ENABLE_I2C_DEV_RELOAD=1).
bus1="${BUS1:-}"
bus2="${BUS2:-}"

# Critical ddcutil options to prevent lockups
ddcutil_options="--disable-cross-instance-locks --sleep-multiplier 0.5"

detect_buses() {
    local detected=()
    while IFS= read -r dev; do
        dev="${dev##*/dev/i2c-}"
        [[ -n "$dev" ]] && detected+=("$dev")
    done < <(ddcutil detect 2>/dev/null | awk '/I2C bus:/{print $NF}')

    if [[ -z "$bus1" && ${#detected[@]} -ge 1 ]]; then bus1="${detected[0]}"; fi
    if [[ -z "$bus2" && ${#detected[@]} -ge 2 ]]; then bus2="${detected[1]}"; fi
}

detect_buses

# Set brightness if argument provided
if [ -n "$1" ]; then
    if [[ -z "$bus1" ]]; then
        echo "No DDC/CI I2C bus detected (set BUS1/BUS2 or install/configure ddcutil)." >&2
        exit 1
    fi

    if [[ "${ENABLE_I2C_DEV_RELOAD:-0}" == "1" ]]; then
        pkexec bash -c 'rmmod i2c_dev 2>/dev/null; modprobe i2c_dev'
    fi

    # Process monitor 1
    if [[ "$1" =~ ^[+-] ]]; then
        current1=$(ddcutil -b "$bus1" $ddcutil_options getvcp 10 -t | awk '{print $4}')
        new1=$((current1 + $1))
        new1=$((new1 < 0 ? 0 : new1 > 100 ? 100 : new1))
        ddcutil -b "$bus1" $ddcutil_options setvcp 10 $new1
    else
        ddcutil -b "$bus1" $ddcutil_options setvcp 10 "$1"
    fi

    # Process monitor 2
    if [[ -n "$bus2" ]]; then
        if [[ "$1" =~ ^[+-] ]]; then
            current2=$(ddcutil -b "$bus2" $ddcutil_options getvcp 10 -t | awk '{print $4}')
            new2=$((current2 + $1))
            new2=$((new2 < 0 ? 0 : new2 > 100 ? 100 : new2))
            ddcutil -b "$bus2" $ddcutil_options setvcp 10 $new2
        else
            ddcutil -b "$bus2" $ddcutil_options setvcp 10 "$1"
        fi
    fi
    exit 0
fi

# Get brightness (single read per monitor)
brightness1=$(ddcutil -b "$bus1" $ddcutil_options getvcp 10 -t 2>/dev/null | awk '{print $4}')
brightness2=""
if [[ -n "$bus2" ]]; then
    brightness2=$(ddcutil -b "$bus2" $ddcutil_options getvcp 10 -t 2>/dev/null | awk '{print $4}')
fi

# Output format: "M1%/M2%"
echo "${brightness1:-?}/${brightness2:-?}"