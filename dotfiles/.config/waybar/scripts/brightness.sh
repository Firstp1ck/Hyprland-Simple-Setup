#!/usr/bin/env bash

# Usage: brightness.sh +10  (or -10, or 50 for absolute)
for bus in 8 9; do
    if [[ "$1" =~ ^[+-] ]]; then
        # Get current brightness
        current=$(ddcutil -b $bus getvcp 10 -t | awk '{print $4}')
        # Calculate new brightness (relative change)
        new=$((current + $1))
        # Ensure value stays within 0-100 range
        new=$((new < 0 ? 0 : new > 100 ? 100 : new))
        # Set new brightness
        ddcutil -b $bus setvcp 10 $new
    else
        # Absolute value (e.g., 50 for 50%)
        ddcutil -b $bus setvcp 10 "$1"
    fi
done