#!/usr/bin/env bash
set -euo pipefail

XDG_MENU_PREFIX=arch- kbuildsycoca6
if [[ -n ${DOLPHIN_FIX_STAMP:-} ]]; then
    touch "$DOLPHIN_FIX_STAMP"
fi
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
    startup_state=${HSS_STARTUP_STATE_HELPER:-$script_dir/startup_state.sh}
    if [[ ! -x $startup_state ]] || ! "$startup_state" mark dolphin; then
        printf '%s\n' 'fix-dolphin: could not publish current-session readiness' >&2
        exit 1
    fi
elif [[ -z ${DOLPHIN_FIX_STAMP:-} ]]; then
    printf '%s\n' 'fix-dolphin: cannot publish readiness outside a Hyprland session' >&2
    exit 1
fi
