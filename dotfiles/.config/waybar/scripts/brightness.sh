#!/usr/bin/env bash

# shellcheck disable=SC2086
# Double quote to prevent globbing and word splitting.

# Hardcoded bus numbers for your monitors (REPLACE WITH YOUR ACTUAL BUS NUMBERS)
bus1=8   # Monitor 1 bus (find with: ddcutil detect)
bus2=9   # Monitor 2 bus

# Critical ddcutil options to prevent lockups
ddcutil_options="--disable-cross-instance-locks --sleep-multiplier 0.5"

# Set brightness if argument provided
if [ -n "$1" ]; then
    # Kernel workaround to prevent I2C bus hangs (now using pkexec for polkit)
    pkexec bash -c 'rmmod i2c_dev 2>/dev/null; modprobe i2c_dev'

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
    if [[ "$1" =~ ^[+-] ]]; then
        current2=$(ddcutil -b "$bus2" $ddcutil_options getvcp 10 -t | awk '{print $4}')
        new2=$((current2 + $1))
        new2=$((new2 < 0 ? 0 : new2 > 100 ? 100 : new2))
        ddcutil -b "$bus2" $ddcutil_options setvcp 10 $new2
    else
        ddcutil -b "$bus2" $ddcutil_options setvcp 10 "$1"
    fi
    exit 0
fi

# Get brightness (single read per monitor)
brightness1=$(ddcutil -b "$bus1" $ddcutil_options getvcp 10 -t 2>/dev/null | awk '{print $4}')
brightness2=$(ddcutil -b "$bus2" $ddcutil_options getvcp 10 -t 2>/dev/null | awk '{print $4}')

# Output format: "M1%/M2%"
echo "${brightness1:-?}/${brightness2:-?}"