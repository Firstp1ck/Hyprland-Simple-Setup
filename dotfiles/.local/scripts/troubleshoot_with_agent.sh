#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
python=$(command -v python3) || {
    printf '%s\n' 'agent-triage: python3 is unavailable' >&2
    exit 1
}
exec "$python" "$script_dir/troubleshoot_with_agent.py" "$@"
