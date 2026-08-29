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

password_keepalive_out="$fixture/password-keepalive.out"
sudo_cache="$fixture/sudo-cache"
: > "$STUB_LOG"
SUDO_PASSWORD='tui-provided-password' \
STUB_SUDO_REQUIRE_PASSWORD=1 \
STUB_SUDO_EXPECTED_PASSWORD='tui-provided-password' \
STUB_SUDO_CACHE_FILE="$sudo_cache" \
HSS_RELIABILITY_ACTION=keepalive \
HSS_KEEPALIVE_INTERVAL=1 \
HSS_HOLD_SECONDS=1 \
  "$repo_root/setup.sh" --test-scenario reliability >"$password_keepalive_out" 2>&1
password_keepalive_pid=$(head -n1 "$password_keepalive_out")
[[ -f $sudo_cache ]]
grep -Fq 'sudo -n -v' "$STUB_LOG"
grep -Fq "sudo -S -p '' -v" "$STUB_LOG"
if grep -Fq 'tui-provided-password' "$STUB_LOG"; then
  printf 'not ok - password leaked into sudo command log\n'
  exit 1
fi
if kill -0 "$password_keepalive_pid" 2>/dev/null; then
  printf 'not ok - password keepalive still alive: %s\n' "$password_keepalive_pid"
  exit 1
fi
printf 'ok - TUI password seeds and maintains unattended sudo credentials\n'

nested_sudo_out="$fixture/nested-sudo.out"
nested_sudo_cache="$fixture/nested-sudo-cache"
: > "$STUB_LOG"
SUDO_PASSWORD='tui-provided-password' \
STUB_SUDO_REQUIRE_PASSWORD=1 \
STUB_SUDO_EXPECTED_PASSWORD='tui-provided-password' \
STUB_SUDO_CACHE_FILE="$nested_sudo_cache" \
HSS_RELIABILITY_ACTION=nested-sudo \
  "$repo_root/setup.sh" --test-scenario reliability >"$nested_sudo_out" 2>&1
grep -Fq "sudo -S -p '' -n true" "$STUB_LOG"
if grep -Fq 'tui-provided-password' "$STUB_LOG"; then
  printf 'not ok - nested sudo leaked the password into the command log\n'
  exit 1
fi
printf 'ok - nested Bash tools inherit password-backed sudo\n'

yay_checkout="$fixture/existing-yay"
mkdir -p "$yay_checkout"
git -C "$yay_checkout" init -q
git -C "$yay_checkout" config user.name test
git -C "$yay_checkout" config user.email test@example.invalid
printf 'pkgname=yay\npkgver=1\npkgrel=1\narch=(any)\n' > "$yay_checkout/PKGBUILD"
git -C "$yay_checkout" add PKGBUILD
git -C "$yay_checkout" commit -qm initial
git -C "$yay_checkout" remote add origin https://aur.archlinux.org/yay.git
yay_bootstrap_out="$fixture/yay-bootstrap.out"
yay_sudo_cache="$fixture/yay-sudo-cache"
: > "$STUB_LOG"
SUDO_PASSWORD='tui-provided-password' \
STUB_SUDO_REQUIRE_PASSWORD=1 \
STUB_SUDO_EXPECTED_PASSWORD='tui-provided-password' \
STUB_SUDO_CACHE_FILE="$yay_sudo_cache" \
HSS_YAY_DIR="$yay_checkout" \
HSS_RELIABILITY_ACTION=yay-bootstrap \
  "$repo_root/setup.sh" --test-scenario reliability >"$yay_bootstrap_out" 2>&1
grep -Fq "Reusing existing yay checkout: $yay_checkout" "$yay_bootstrap_out"
grep -Fq "makepkg cwd=$yay_checkout" "$STUB_LOG"
grep -Fq -- '--config' "$STUB_LOG"
grep -Fq 'makepkg-auth=' "$STUB_LOG"
grep -Fq "sudo -S -p '' -- /usr/bin/true" "$STUB_LOG"
if grep -Fq 'tui-provided-password' "$STUB_LOG"; then
  printf 'not ok - yay bootstrap leaked the password into the command log\n'
  exit 1
fi
printf 'ok - yay bootstrap reuses checkout and supplies explicit makepkg authentication\n'
