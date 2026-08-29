#!/usr/bin/env bash
# Launch Waybar with a validated machine-local generated config.

set -euo pipefail

readonly CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar"
readonly CONFIG_FILE="$CACHE_DIR/config.generated.jsonc"
readonly UPDATE_SCRIPT="$HOME/.config/waybar/scripts/lmstudio_update_config.sh"

notify_error() {
    local message="$1"

    printf 'waybar_launch.sh: %s\n' "$message" >&2
    if command -v notify-send >/dev/null 2>&1; then
        notify-send --urgency=critical "Waybar startup failed" "$message" || true
    fi
}

validate_generated_config() {
    [[ -s "$CONFIG_FILE" ]] || return 1

    python3 - "$CONFIG_FILE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except (OSError, UnicodeError, json.JSONDecodeError) as exc:
    print(f"Invalid generated Waybar config: {exc}", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(data, (dict, list)):
    print("Generated Waybar config must contain an object or array.", file=sys.stderr)
    raise SystemExit(1)
PY
}

mkdir -p "$CACHE_DIR"

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

generation_output=""
if generation_output="$("$UPDATE_SCRIPT" 2>&1)"; then
    # Successful generation can still omit unsafe model identifiers or report
    # unavailable optional hardware. Show a bounded warning summary at startup.
    warning_count=0
    omitted_warning_count=0
    while IFS= read -r line; do
        [[ "$line" == Warning:* ]] || continue
        warning_count=$((warning_count + 1))
        if ((warning_count <= 5)); then
            printf '%s\n' "$line" >&2
        else
            omitted_warning_count=$((omitted_warning_count + 1))
        fi
    done <<<"$generation_output"
    if ((omitted_warning_count > 0)); then
        printf 'Warning: %d additional generation warning(s) omitted.\n' "$omitted_warning_count" >&2
    fi
else
    error_summary=""
    fallback_summary=""
    while IFS= read -r line; do
        [[ -n "$line" && -z "$fallback_summary" ]] && fallback_summary="$line"
        if [[ "$line" == Error:* ]]; then
            error_summary="$line"
            break
        fi
    done <<<"$generation_output"

    [[ -n "$error_summary" ]] || error_summary="${fallback_summary:-Generated configuration could not be created.}"
    notify_error "$error_summary"
    [[ -n "$generation_output" ]] && printf '%s\n' "$generation_output" | head -n 12 >&2
    exit 1
fi

if ! validate_generated_config; then
    notify_error "The generated configuration is missing or invalid. Waybar was not started."
    exit 1
fi

if ! command -v waybar >/dev/null 2>&1; then
    notify_error "The waybar executable was not found."
    exit 1
fi

exec waybar -c "$CONFIG_FILE"
