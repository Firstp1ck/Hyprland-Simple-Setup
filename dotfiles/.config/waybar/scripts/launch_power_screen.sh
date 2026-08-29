#!/usr/bin/env bash
# Launch wlogout with the wallpaper currently active in hyprpaper.

set -u

readonly CACHE_DIR="$HOME/.cache/wlogout"
readonly BACKGROUND_LINK="$CACHE_DIR/current-wallpaper"
readonly WLOGOUT_STYLE="$HOME/.config/wlogout/style.css"

if ! command -v wlogout >/dev/null 2>&1; then
    command -v notify-send >/dev/null 2>&1 && \
        notify-send --urgency=critical "Power screen" "wlogout is not installed." || true
    exit 1
fi

mkdir -p "$CACHE_DIR" || exit 1

if [[ ! -f "$BACKGROUND_LINK" ]]; then
    command -v notify-send >/dev/null 2>&1 && \
        notify-send --urgency=normal "Power screen" "No current wallpaper is cached; using the fallback background." || true
fi

exec wlogout --protocol layer-shell --css "$WLOGOUT_STYLE"
