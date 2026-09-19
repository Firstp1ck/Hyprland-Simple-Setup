#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
PYTHONDONTWRITEBYTECODE=1 python3 "$repo_root/dotfiles/.local/scripts/tests/test_troubleshoot_with_agent.py" -v
