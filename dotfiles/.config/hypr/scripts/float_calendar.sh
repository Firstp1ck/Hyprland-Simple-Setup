#!/usr/bin/env bash
set -euo pipefail

exec "$HOME/.config/hypr/scripts/term_exec.sh" \
  --app-id hss-calendar --title calcurse -- calcurse
