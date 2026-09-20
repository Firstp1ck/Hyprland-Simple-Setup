#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"

fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults
state="$XDG_STATE_HOME/hyprland-simple-setup"
source_service="$HOME/dotfiles/.local/share/dbus-1/services/org.freedesktop.Notifications.service"
runtime_service="$HOME/.local/share/dbus-1/services/org.freedesktop.Notifications.service"
mkdir -p "$(dirname -- "$runtime_service")"
ln -s "$source_service" "$runtime_service"
printf 'updated service\n' > "$fixture/service"

HSS_RELIABILITY_ACTION=atomic HSS_DEST="$runtime_service" HSS_SOURCE="$fixture/service" \
  "$repo_root/setup.sh" --test-scenario reliability >/dev/null
update_run=$(<"$state/latest-run")
[[ -L $runtime_service ]]
[[ $(<"$source_service") == 'updated service' ]]
grep -q $'^symlink-target\t' "$state/runs/$update_run/manifest.tsv"
HSS_RELIABILITY_ACTION=rollback HSS_ROLLBACK_RUN_ID="$update_run" \
  "$repo_root/setup.sh" --test-scenario reliability >/dev/null
[[ -L $runtime_service ]]
grep -Fq 'org.freedesktop.Notifications' "$source_service"
printf 'ok - notification D-Bus override updates atomically through its exact runtime symlink and rolls back\n'

rm -f "$runtime_service" "$source_service"
HSS_RELIABILITY_ACTION=atomic HSS_DEST="$runtime_service" HSS_SOURCE="$fixture/service" \
  "$repo_root/setup.sh" --test-scenario reliability >/dev/null
create_run=$(<"$state/latest-run")
[[ -f $runtime_service && ! -L $runtime_service ]]
HSS_RELIABILITY_ACTION=rollback HSS_ROLLBACK_RUN_ID="$create_run" \
  "$repo_root/setup.sh" --test-scenario reliability >/dev/null
[[ ! -e $runtime_service ]]
printf 'ok - rollback deletes an unchanged setup-created notification override\n'

adjacent="$HOME/.local/share/dbus-1/services/org.example.Notifications.service"
if output=$(HSS_RELIABILITY_ACTION=atomic HSS_DEST="$adjacent" HSS_SOURCE="$fixture/service" \
  "$repo_root/setup.sh" --test-scenario reliability 2>&1); then
  printf 'not ok - adjacent D-Bus service path was accepted\n' >&2
  exit 1
fi
grep -Fq 'outside approved roots' <<<"$output"
[[ ! -e $adjacent ]]

outside="$fixture/outside.service"
printf 'outside\n' > "$outside"
ln -s "$outside" "$runtime_service"
if output=$(HSS_RELIABILITY_ACTION=atomic HSS_DEST="$runtime_service" HSS_SOURCE="$fixture/service" \
  "$repo_root/setup.sh" --test-scenario reliability 2>&1); then
  printf 'not ok - escaping notification service symlink was accepted\n' >&2
  exit 1
fi
grep -Fq 'outside approved roots' <<<"$output"
[[ $(<"$outside") == outside ]]
printf 'ok - adjacent paths and escaping notification service symlinks are refused\n'

fake_id=20000101T000012Z-000012
mkdir -p "$state/runs/$fake_id/backup"
printf 'start=x\nend=x\nexit=0\n' > "$state/runs/$fake_id/meta"
hash=$(printf x | sha256sum | cut -d' ' -f1)
printf 'created\t%s\t-\t%s\t-\n' "$adjacent" "$hash" > "$state/runs/$fake_id/manifest.tsv"
if output=$(HSS_RELIABILITY_ACTION=rollback HSS_ROLLBACK_RUN_ID="$fake_id" \
  "$repo_root/setup.sh" --test-scenario reliability 2>&1); then
  printf 'not ok - rollback accepted adjacent D-Bus service destination\n' >&2
  exit 1
fi
grep -Fq 'out-of-scope destination' <<<"$output"
printf 'ok - rollback rejects malformed adjacent notification service destinations\n'
