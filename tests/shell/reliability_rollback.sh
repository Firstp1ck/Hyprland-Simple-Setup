#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults
state="$XDG_STATE_HOME/hyprland-simple-setup"
target="$HOME/dotfiles/.config/hypr/rollback.conf"
unrelated="$HOME/dotfiles/.config/hypr/unrelated.conf"
printf 'original\n' > "$target"
printf 'untouched\n' > "$unrelated"
printf 'setup\n' > "$fixture/source"
HSS_RELIABILITY_ACTION=atomic HSS_DEST="$target" HSS_SOURCE="$fixture/source" "$repo_root/setup.sh" --test-scenario reliability
source_run=$(cat "$state/latest-run")
HSS_RELIABILITY_ACTION=rollback HSS_ROLLBACK_RUN_ID="$source_run" "$repo_root/setup.sh" --test-scenario reliability >/dev/null
[[ $(cat "$target") == original && $(cat "$unrelated") == untouched ]]
printf 'ok - rollback restores only the manifest destination\n'

created="$HOME/dotfiles/.config/hypr/created.conf"
printf 'created by setup\n' > "$fixture/source"
HSS_RELIABILITY_ACTION=atomic HSS_DEST="$created" HSS_SOURCE="$fixture/source" "$repo_root/setup.sh" --test-scenario reliability
created_run=$(cat "$state/latest-run")
[[ -f $created ]]
HSS_RELIABILITY_ACTION=rollback HSS_ROLLBACK_RUN_ID="$created_run" "$repo_root/setup.sh" --test-scenario reliability >/dev/null
[[ ! -e $created ]]
printf 'ok - rollback deletes an unchanged setup-created file\n'

# A later user edit fails closed without confirmation.
printf 'setup2\n' > "$fixture/source"
HSS_RELIABILITY_ACTION=atomic HSS_DEST="$target" HSS_SOURCE="$fixture/source" "$repo_root/setup.sh" --test-scenario reliability
mismatch_run=$(cat "$state/latest-run")
printf 'user edit\n' > "$target"
set +e
mismatch=$(HSS_RELIABILITY_ACTION=rollback HSS_ROLLBACK_RUN_ID="$mismatch_run" "$repo_root/setup.sh" --test-scenario reliability 2>&1)
status=$?
set -e
[[ $status -ne 0 ]]
grep -q 'digest mismatch requires interactive confirmation' <<< "$mismatch"
[[ $(cat "$target") == 'user edit' ]]
printf 'ok - rollback refuses current-digest mismatch non-interactively\n'

make_fake() {
  local id=$1 row=$2
  mkdir -p "$state/runs/$id/backup"
  printf 'start=x\nend=x\nexit=0\n' > "$state/runs/$id/meta"
  printf '%b\n' "$row" > "$state/runs/$id/manifest.tsv"
}
run_refusal() {
  local id=$1 expected=$2 output result
  set +e
  output=$(HSS_RELIABILITY_ACTION=rollback HSS_ROLLBACK_RUN_ID="$id" "$repo_root/setup.sh" --test-scenario reliability 2>&1)
  result=$?
  set -e
  [[ $result -ne 0 ]]
  grep -qi "$expected" <<< "$output"
}

hash=$(printf x | sha256sum | cut -d' ' -f1)
make_fake 20000101T000001Z-000001 "invalid\t$target\t$hash\t$hash\tbackup/x"
run_refusal 20000101T000001Z-000001 'invalid kind'
make_fake 20000101T000002Z-000002 "created\t$target\t-\tbad\t-"
run_refusal 20000101T000002Z-000002 'invalid after digest'
make_fake 20000101T000003Z-000003 "created\t$target\t-\t$hash\t-\ncreated\t$target\t-\t$hash\t-"
run_refusal 20000101T000003Z-000003 'duplicate destination'
make_fake 20000101T000004Z-000004 "modified\t$target\t$hash\t$hash\t../escape"
run_refusal 20000101T000004Z-000004 'invalid backup fields'
make_fake 20000101T000005Z-000005 "created\t/tmp/outside\t-\t$hash\t-"
run_refusal 20000101T000005Z-000005 'out-of-scope'
make_fake 20000101T000006Z-000006 "created\t$target\t-\t$hash"
run_refusal 20000101T000006Z-000006 'five columns'
mkdir -p "$state/runs/20000101T000007Z-000007/backup"
printf bad > "$state/runs/20000101T000007Z-000007/backup/x"
printf 'start=x\nend=x\nexit=0\n' > "$state/runs/20000101T000007Z-000007/meta"
printf 'modified\t%s\t%s\t%s\tbackup/x\n' "$target" "$hash" "$hash" > "$state/runs/20000101T000007Z-000007/manifest.tsv"
run_refusal 20000101T000007Z-000007 'corrupted backup'
make_fake 20000101T000008Z-000008 "modified\t$target\t$hash\t$hash\tbackup/missing"
run_refusal 20000101T000008Z-000008 'missing backup'
escape_link="$HOME/dotfiles/.config/hypr/escape"
ln -s /tmp "$escape_link"
make_fake 20000101T000009Z-000009 "created\t$escape_link/file\t-\t$hash\t-"
run_refusal 20000101T000009Z-000009 'non-canonical destination'
mkdir -p "$fixture/outside-run/backup"
printf 'start=x\nend=x\nexit=0\n' > "$fixture/outside-run/meta"
: > "$fixture/outside-run/manifest.tsv"
ln -s "$fixture/outside-run" "$state/runs/20000101T000010Z-000010"
run_refusal 20000101T000010Z-000010 'run directory traversal'
make_fake 20000101T000011Z-000011 "created\t$target\t-\t$hash\t-"
printf 'start=x\n' > "$state/runs/20000101T000011Z-000011/meta"
run_refusal 20000101T000011Z-000011 'malformed or incomplete meta'
set +e
traversal=$("$repo_root/setup.sh" --rollback ../etc 2>&1); status=$?
set -e
[[ $status -ne 0 ]]
grep -q 'invalid run ID' <<< "$traversal"
printf 'ok - rollback validation rejects malformed, duplicate, traversal, corrupt, and out-of-scope manifests\n'
