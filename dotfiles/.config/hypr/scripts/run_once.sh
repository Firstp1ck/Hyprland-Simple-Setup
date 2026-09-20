#!/usr/bin/env bash

set -u

if [[ $# -lt 2 ]]; then
    printf 'Usage: %s <key> <command> [args...]\n' "${0##*/}" >&2
    exit 2
fi

key=$1
shift
if [[ ! $key =~ ^[A-Za-z0-9._-]+$ ]]; then
    printf 'Invalid run-once key: %s\n' "$key" >&2
    exit 2
fi

runtime_dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
instance=${HYPRLAND_INSTANCE_SIGNATURE:-hyprland}
lock_dir="$runtime_dir/hyprland-simple-setup"
umask 077
mkdir -p -- "$lock_dir" || exit 1

exec {lock_fd}>"$lock_dir/autostart-${instance}-${key}.lock" || exit 1
if ! flock -n "$lock_fd"; then
    exit 0
fi

exec "$@"
