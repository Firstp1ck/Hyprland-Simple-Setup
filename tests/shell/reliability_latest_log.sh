#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults
state="$XDG_STATE_HOME/hyprland-simple-setup"
HSS_RELIABILITY_ACTION=lock-hold HSS_HOLD_SECONDS=0 "$repo_root/setup.sh" --test-scenario reliability >/dev/null
run=$(cat "$state/latest-run")
printf '[2026-01-01 00:00:00] [WARNING] latest warning\n[2026-01-01 00:00:01] [WARNING] latest warning\n' > "$state/runs/$run/log"
HSS_WARNING_DELAY=0 "$HOME/dotfiles/.config/hypr/scripts/check_setup_warnings.sh"
[[ $(grep -c 'latest warning' "$STUB_LOG") -eq 1 ]]
: > "$STUB_LOG"
printf '[WARNING] outside warning\n' > "$fixture/outside.log"
rm "$state/runs/$run/log"
ln -s "$fixture/outside.log" "$state/runs/$run/log"
HSS_WARNING_DELAY=0 "$HOME/dotfiles/.config/hypr/scripts/check_setup_warnings.sh"
[[ ! -s $STUB_LOG ]]
printf '../escape\n' > "$state/latest-run"
HSS_WARNING_DELAY=0 "$HOME/dotfiles/.config/hypr/scripts/check_setup_warnings.sh"
[[ ! -s $STUB_LOG ]]
printf 'ok - warning checker validates latest-run and reads only its run log\n'
