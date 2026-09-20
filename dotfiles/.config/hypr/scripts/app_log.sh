#!/usr/bin/env bash

# Source-only helper. Keep dmenu's stdout and stdin untouched.
hss_start_app_log() {
    local name=$1
    case "$name" in launcher|bar|dock) ;; *) return 2 ;; esac
    local directory="${XDG_STATE_HOME:-$HOME/.local/state}/hyprland-simple-setup/apps"
    local file="$directory/$name.log"
    if (umask 077; mkdir -p -- "$directory" && printf '\n[START] %(%Y-%m-%dT%H:%M:%S%z)T %s\n' -1 "$name" >> "$file"); then
        exec 2>> "$file"
    else
        printf 'Warning: Cannot save %s startup errors to %s\n' "$name" "$file" >&2
    fi
}
