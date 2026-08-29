#!/usr/bin/env bash
# Preserve update details while adding the Waybar interaction hint.

set -euo pipefail

readonly HINT=$'Left click: start system update\nRight click: update options'

updates_pid=""
formatter_pid=""

# Waybar ends this wrapper during reload; the EXIT trap owns both child processes.
# shellcheck disable=SC2329
cleanup() {
    local exit_status=$?

    trap - EXIT HUP INT TERM

    if [[ -n "$formatter_pid" ]]; then
        kill "$formatter_pid" 2>/dev/null || true
    fi
    if [[ -n "$updates_pid" ]]; then
        kill "$updates_pid" 2>/dev/null || true
    fi

    [[ -z "$formatter_pid" ]] || wait "$formatter_pid" 2>/dev/null || true
    [[ -z "$updates_pid" ]] || wait "$updates_pid" 2>/dev/null || true

    exit "$exit_status"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

exec {updates_fd}< <(
    exec waybar-module-pacman-updates \
        --no-zero-output \
        --interval-seconds 60 \
        --network-interval-seconds 60 \
        --tooltip-align-columns monospace
)
updates_pid=$!

jq --unbuffered --compact-output --arg hint "$HINT" '
    (.tooltip // "" | tostring) as $current
    | .tooltip = (
        if ($current | length) == 0 then
            $hint
        else
            $hint + "\n\n" + $current
        end
    )
' <&"$updates_fd" &
formatter_pid=$!
exec {updates_fd}<&-

set +e
wait "$formatter_pid"
formatter_status=$?
formatter_pid=""

# If the formatter exits first, stop the long-running update producer too.
if kill -0 "$updates_pid" 2>/dev/null; then
    kill "$updates_pid" 2>/dev/null || true
fi
wait "$updates_pid"
updates_status=$?
updates_pid=""
set -e

if ((formatter_status != 0)); then
    exit "$formatter_status"
fi
exit "$updates_status"
