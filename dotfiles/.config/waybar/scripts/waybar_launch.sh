#!/usr/bin/env bash
# Launch Waybar after validating the checked-in configuration.

set -euo pipefail

readonly CONFIG_FILE="$HOME/.config/waybar/config.jsonc"

notify_error() {
    local message="$1"

    printf 'waybar_launch.sh: %s\n' "$message" >&2
    if command -v notify-send >/dev/null 2>&1; then
        notify-send --urgency=critical "Waybar startup failed" "$message" || true
    fi
}

validate_config() {
    [[ -s "$CONFIG_FILE" ]] || return 1

    python3 - "$CONFIG_FILE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except (OSError, UnicodeError, json.JSONDecodeError) as exc:
    print(f"Invalid Waybar config: {exc}", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(data, (dict, list)):
    print("Waybar config must contain an object or array.", file=sys.stderr)
    raise SystemExit(1)
PY
}

# Waybar's tray/module startup can block on xdg-desktop-portal during session boot.
# Wait briefly for the portal bus name instead of racing its DBus timeout.
if command -v gdbus >/dev/null 2>&1; then
    for _ in {1..20}; do
        if gdbus call \
            --session \
            --dest org.freedesktop.portal.Desktop \
            --object-path /org/freedesktop/portal/desktop \
            --method org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
            break
        fi
        sleep 0.25
    done
fi

if ! validate_config; then
    notify_error "The Waybar configuration is missing or invalid. Waybar was not started."
    exit 1
fi

if ! command -v waybar >/dev/null 2>&1; then
    notify_error "The waybar executable was not found."
    exit 1
fi

exec waybar -c "$CONFIG_FILE"
