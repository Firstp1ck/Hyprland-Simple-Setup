#!/usr/bin/env bash

state_root="${XDG_STATE_HOME:-$HOME/.local/state}/hyprland-simple-setup"
latest_pointer="$state_root/latest-run"

sleep "${HSS_WARNING_DELAY:-3}"
command -v notify-send >/dev/null 2>&1 || exit 0
[[ -f $latest_pointer && ! -L $latest_pointer ]] || exit 0

run_id=$(cat -- "$latest_pointer")
[[ $run_id =~ ^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}$ ]] || exit 0
run_dir="$state_root/runs/$run_id"
canonical_runs=$(readlink -m -- "$state_root/runs")
canonical_run=$(readlink -f -- "$run_dir" 2>/dev/null) || exit 0
[[ $canonical_run == "$canonical_runs/$run_id" ]] || exit 0
log_file="$canonical_run/log"
[[ -f $log_file && ! -L $log_file ]] || exit 0
canonical_log=$(readlink -f -- "$log_file" 2>/dev/null) || exit 0
[[ $canonical_log == "$canonical_run/log" ]] || exit 0

mapfile -t warnings < <(awk '/\[WARNING\]/ { sub(/^.*\[WARNING\] /,""); if (!seen[$0]++) print }' "$log_file")
for warning in "${warnings[@]}"; do
    [[ -n $warning ]] || continue
    notify-send -u critical -t 0 "Hyprland Setup - Warning" "$warning"
done
