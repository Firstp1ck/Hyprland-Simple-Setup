#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'Usage: %s {init|mark|has|path} [numlock|wallpaper|dolphin]\n' "${0##*/}" >&2
}

command_name=${1:-}
marker=${2:-}
case "$command_name" in
    init) [[ $# -eq 1 ]] || { usage; exit 2; } ;;
    mark|has|path)
        [[ $# -eq 2 && $marker =~ ^(numlock|wallpaper|dolphin)$ ]] || { usage; exit 2; }
        ;;
    *) usage; exit 2 ;;
esac

session=${HYPRLAND_INSTANCE_SIGNATURE:-}
[[ -n $session && $session != *$'\n'* && $session != *$'\r'* ]] || {
    printf '%s\n' 'startup-state: HYPRLAND_INSTANCE_SIGNATURE is unavailable' >&2
    exit 1
}
uid=$(id -u)
runtime=${XDG_RUNTIME_DIR:-/run/user/$uid}
root=${HSS_STARTUP_STATE_ROOT:-$runtime/hyprland-simple-setup/startup}
session_hash=$(printf '%s' "$session" | sha256sum | cut -d' ' -f1)
session_dir=$root/$uid-$session_hash

ensure_directory() {
    mkdir -p -- "$session_dir"
    [[ -d $root && ! -L $root && -O $root && -d $session_dir && ! -L $session_dir && -O $session_dir ]] || {
        printf '%s\n' 'startup-state: state directory is not safely owned' >&2
        return 1
    }
    chmod 700 -- "$root" "$session_dir"
}

marker_path=$session_dir/$marker.ready
case "$command_name" in
    init)
        ensure_directory
        printf '%s\n' "$session_dir"
        ;;
    path)
        ensure_directory
        printf '%s\n' "$marker_path"
        ;;
    has)
        ensure_directory
        [[ -f $marker_path && ! -L $marker_path && -O $marker_path && $(stat -c '%a' -- "$marker_path") == 600 ]]
        ;;
    mark)
        ensure_directory
        temporary=$(mktemp -- "$session_dir/.${marker}.XXXXXX")
        trap 'rm -f -- "${temporary:-}"' EXIT
        chmod 600 -- "$temporary"
        printf '%s\n' "$(date --iso-8601=seconds)" > "$temporary"
        mv -f -- "$temporary" "$marker_path"
        temporary=
        ;;
esac
