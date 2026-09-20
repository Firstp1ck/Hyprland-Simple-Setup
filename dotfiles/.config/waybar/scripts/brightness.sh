#!/usr/bin/env bash
set -euo pipefail

# BUS1/BUS2 override detection. Kernel reloads require ENABLE_I2C_DEV_RELOAD=1.
bus1=${BUS1:-}
bus2=${BUS2:-}
ddcutil_options=(--disable-cross-instance-locks --sleep-multiplier 0.5)

for bus in "$bus1" "$bus2"; do
    if [[ -n $bus && ! $bus =~ ^[0-9]+$ ]]; then
        printf 'BUS1 and BUS2 must be numeric I2C bus numbers.\n' >&2
        exit 1
    fi
done

adjustment=${1:-}
if [[ -n $adjustment && ! $adjustment =~ ^[+-]?[0-9]{1,3}$ ]]; then
    printf 'Brightness must be a percentage or signed adjustment.\n' >&2
    exit 1
fi

if [[ -z $bus1 || -z $bus2 ]]; then
    while IFS= read -r device; do
        bus=${device##*/dev/i2c-}
        [[ $bus =~ ^[0-9]+$ ]] || continue
        [[ $bus != "$bus1" && $bus != "$bus2" ]] || continue
        if [[ -z $bus1 ]]; then
            bus1=$bus
        elif [[ -z $bus2 ]]; then
            bus2=$bus
        fi
    done < <(ddcutil detect 2>/dev/null | awk '/I2C bus:/{print $NF}')
fi

read_brightness() {
    local current
    current=$(ddcutil -b "$1" "${ddcutil_options[@]}" getvcp 10 -t | awk '{print $4}') || return 1
    [[ $current =~ ^[0-9]{1,3}$ ]] || return 1
    printf '%d\n' "$((10#$current))"
}

if [[ -n $adjustment ]]; then
    if [[ -z $bus1 && -z $bus2 ]]; then
        printf 'No DDC/CI I2C bus detected. Set BUS1/BUS2 or configure ddcutil.\n' >&2
        exit 1
    fi
    if [[ ${ENABLE_I2C_DEV_RELOAD:-0} == 1 ]]; then
        pkexec bash -c 'rmmod i2c_dev 2>/dev/null; modprobe i2c_dev'
    fi

    digits=${adjustment#[+-]}
    value=$((10#$digits))
    [[ $adjustment != -* ]] || value=$((-value))
    for bus in "$bus1" "$bus2"; do
        [[ -n $bus ]] || continue
        if [[ $adjustment == [+-]* ]]; then
            current=$(read_brightness "$bus")
            target=$((current + value))
        else
            target=$value
        fi
        target=$((target < 0 ? 0 : target > 100 ? 100 : target))
        ddcutil -b "$bus" "${ddcutil_options[@]}" setvcp 10 "$target"
    done
    exit 0
fi

brightness1='?'
brightness2='?'
if [[ -n $bus1 ]]; then
    brightness1=$(read_brightness "$bus1" 2>/dev/null) || brightness1='?'
fi
if [[ -n $bus2 ]]; then
    brightness2=$(read_brightness "$bus2" 2>/dev/null) || brightness2='?'
fi
printf '%s/%s\n' "$brightness1" "$brightness2"
