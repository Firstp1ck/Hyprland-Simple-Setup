#!/usr/bin/env bash
# Refresh the cache-local LM Studio menu and generated Waybar config.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Refreshing LM Studio menu..."

if "$SCRIPT_DIR/lmstudio_update_config.sh"; then
    echo
    echo "Menu refreshed successfully."
    echo "Reload Waybar with: killall -SIGUSR2 waybar"
else
    echo "Error: Failed to refresh the LM Studio menu." >&2
    exit 1
fi
