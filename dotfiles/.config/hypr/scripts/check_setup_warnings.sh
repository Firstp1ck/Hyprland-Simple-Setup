#!/usr/bin/env bash

LOG_FILE="${HOME}/Linux-Setup.log"

# Give notification daemon a moment to start
sleep 3

# If notify-send is unavailable, exit quietly
if ! command -v notify-send >/dev/null 2>&1; then
	exit 0
fi

# If log doesn't exist, nothing to check
[ -f "$LOG_FILE" ] || exit 0

# Limit to warnings from the most recent run (after the last "Starting Hyprland Setup..." debug entry)
start_line=$(grep -n '\[DEBUG\] Starting Hyprland Setup\.\.\.' "$LOG_FILE" | tail -n1 | cut -d: -f1)
if [[ -n "$start_line" ]]; then
	log_slice=$(tail -n +"$start_line" "$LOG_FILE")
else
	log_slice=$(cat "$LOG_FILE")
fi

# Extract all WARNING messages from the selected slice and notify once per unique message.
# Log format: [YYYY-MM-DD HH:MM:SS] [WARNING] message...
mapfile -t warnings < <(awk '/\[WARNING\]/ { sub(/^.*\[WARNING\] /,""); msg=$0; if (!seen[msg]++) print msg }' <<< "$log_slice")

for w in "${warnings[@]}"; do
	[ -n "$w" ] || continue
	notify-send -u critical -t 0 "Hyprland Setup - Warning" "$w"
done


