#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults

holder_out="$fixture/holder.out"
HSS_RELIABILITY_ACTION=lock-hold HSS_HOLD_SECONDS=3 "$repo_root/setup.sh" --test-scenario reliability >"$holder_out" 2>&1 &
holder=$!
for _ in {1..50}; do grep -q 'holder pid=' "$holder_out" 2>/dev/null && break; sleep 0.05; done
set +e
blocked=$(HSS_RELIABILITY_ACTION=lock-hold HSS_HOLD_SECONDS=0 "$repo_root/setup.sh" --test-scenario reliability 2>&1)
blocked_status=$?
set -e
[[ $blocked_status -eq 2 ]]
grep -Fq "pid $holder" <<< "$blocked"
wait "$holder"
printf 'ok - lock contention exits 2 and reports holder pid\n'

signal_out="$fixture/signal.out"
set +e
HSS_RELIABILITY_ACTION=temp-wait HSS_HOLD_SECONDS=30 timeout --signal=INT 1 "$repo_root/setup.sh" --test-scenario reliability >"$signal_out" 2>&1
signal_status=$?
set -e
[[ $signal_status -eq 124 ]]
temp_path=$(head -n1 "$signal_out")
[[ -n $temp_path && ! -e $temp_path ]]
run_id=$(basename "$(dirname "$(dirname "$temp_path")")")
grep -q '^exit=130$' "$XDG_STATE_HOME/hyprland-simple-setup/runs/$run_id/meta"
printf 'ok - SIGINT re-raises and removes run temporary files\n'

term_out="$fixture/term.out"
set +e
HSS_RELIABILITY_ACTION=temp-wait HSS_HOLD_SECONDS=30 timeout --signal=TERM 1 "$repo_root/setup.sh" --test-scenario reliability >"$term_out" 2>&1
term_status=$?
set -e
[[ $term_status -eq 124 ]]
term_path=$(head -n1 "$term_out")
[[ -n $term_path && ! -e $term_path ]]
term_run=$(basename "$(dirname "$(dirname "$term_path")")")
grep -q '^exit=143$' "$XDG_STATE_HOME/hyprland-simple-setup/runs/$term_run/meta"
printf 'ok - SIGTERM re-raises and removes run temporary files\n'

keepalive_out="$fixture/keepalive.out"
HSS_RELIABILITY_ACTION=keepalive HSS_KEEPALIVE_INTERVAL=1 HSS_HOLD_SECONDS=1 "$repo_root/setup.sh" --test-scenario reliability >"$keepalive_out" 2>&1
keepalive_pid=$(head -n1 "$keepalive_out")
if kill -0 "$keepalive_pid" 2>/dev/null; then
  printf 'not ok - keepalive still alive: %s\n' "$keepalive_pid"
  exit 1
fi
printf 'ok - sudo keepalive is gone after exit\n'
