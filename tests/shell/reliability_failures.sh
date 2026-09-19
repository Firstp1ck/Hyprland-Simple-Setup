#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"

fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults
state="$XDG_STATE_HOME/hyprland-simple-setup"
failure_bin="$fixture/failure-bin"
mkdir -p "$failure_bin"
export HSS_SHIM_REAL_AWK
export HSS_SHIM_REAL_MV
export HSS_SHIM_REAL_RM
HSS_SHIM_REAL_AWK=$(command -v awk)
HSS_SHIM_REAL_MV=$(command -v mv)
HSS_SHIM_REAL_RM=$(command -v rm)
cat > "$failure_bin/awk" <<'SHIM'
#!/usr/bin/env bash
set -euo pipefail
input=${!#}
if [[ -n ${HSS_SHIM_FAIL_AWK_INPUT:-} && $input == "$HSS_SHIM_FAIL_AWK_INPUT" ]] \
    || [[ -n ${HSS_SHIM_FAIL_AWK_SUFFIX:-} && $input == *"$HSS_SHIM_FAIL_AWK_SUFFIX" ]]; then
  printf 'awk failure shim refused input %s\n' "$input" >&2
  exit 71
fi
exec "${HSS_SHIM_REAL_AWK:?}" "$@"
SHIM
cat > "$failure_bin/mv" <<'SHIM'
#!/usr/bin/env bash
set -euo pipefail
destination=${!#}
if [[ -n ${HSS_SHIM_FAIL_MV_DEST:-} && $destination == "$HSS_SHIM_FAIL_MV_DEST" ]] \
    || [[ -n ${HSS_SHIM_FAIL_MV_SUFFIX:-} && $destination == *"$HSS_SHIM_FAIL_MV_SUFFIX" ]]; then
  printf 'mv failure shim refused destination %s\n' "$destination" >&2
  exit 72
fi
exec "${HSS_SHIM_REAL_MV:?}" "$@"
SHIM
cat > "$failure_bin/rm" <<'SHIM'
#!/usr/bin/env bash
set -euo pipefail
target=${!#}
if [[ -n ${HSS_SHIM_FAIL_RM_TARGET:-} && $target == "$HSS_SHIM_FAIL_RM_TARGET" ]]; then
  printf 'rm failure shim refused target %s\n' "$target" >&2
  exit 73
fi
exec "${HSS_SHIM_REAL_RM:?}" "$@"
SHIM
chmod +x "$failure_bin/awk" "$failure_bin/mv" "$failure_bin/rm"

hash_file() {
  sha256sum -- "$1" | awk '{print $1}'
}

make_run() {
  local id=$1 rows=$2 final_newline=${3:-true}
  mkdir -p "$state/runs/$id/backup"
  printf 'start=x\nend=x\nexit=0\n' > "$state/runs/$id/meta"
  if [[ $final_newline == true ]]; then
    printf '%s\n' "$rows" > "$state/runs/$id/manifest.tsv"
  else
    printf '%s' "$rows" > "$state/runs/$id/manifest.tsv"
  fi
}

# RC-01: a dry-run must report both restoration and deletion without changing either file.
dry_modified="$HOME/dotfiles/.config/hypr/dry-modified.conf"
dry_created="$HOME/dotfiles/.config/hypr/dry-created.conf"
printf 'installed modified\n' > "$dry_modified"
printf 'installed created\n' > "$dry_created"
printf 'original modified\n' > "$fixture/dry-backup"
dry_before=$(hash_file "$fixture/dry-backup")
dry_after=$(hash_file "$dry_modified")
dry_created_after=$(hash_file "$dry_created")
dry_id=20010101T000001Z-000001
printf -v dry_rows 'modified\t%s\t%s\t%s\tbackup/modified\ncreated\t%s\t-\t%s\t-' \
  "$dry_modified" "$dry_before" "$dry_after" "$dry_created" "$dry_created_after"
make_run "$dry_id" "$dry_rows"
cp "$fixture/dry-backup" "$state/runs/$dry_id/backup/modified"
dry_output=$(DRY_RUN=true HSS_RELIABILITY_ACTION=rollback HSS_ROLLBACK_RUN_ID="$dry_id" \
  "$repo_root/setup.sh" --test-scenario reliability 2>&1)
[[ $(<"$dry_modified") == 'installed modified' ]]
[[ $(<"$dry_created") == 'installed created' ]]
grep -Fq "would modify $dry_modified" <<<"$dry_output"
grep -Fq "would delete $dry_created" <<<"$dry_output"
grep -Fq 'no files changed' <<<"$dry_output"
printf 'ok - rollback dry-run reports mixed actions without modifying or deleting targets\n'

# RC-02: privileged created rows use sudo after validation, against a synthetic etc root only.
export HSS_TEST_ETC_ROOT="$fixture/etc"
privileged="$HSS_TEST_ETC_ROOT/sddm.conf.d/sddm.conf"
mkdir -p "$(dirname -- "$privileged")"
printf 'installed privileged\n' > "$privileged"
privileged_id=20010101T000002Z-000002
privileged_after=$(hash_file "$privileged")
printf -v privileged_row 'created\t%s\t-\t%s\t-' "$privileged" "$privileged_after"
make_run "$privileged_id" "$privileged_row"
: > "$STUB_LOG"
HSS_RELIABILITY_ACTION=rollback HSS_ROLLBACK_RUN_ID="$privileged_id" \
  "$repo_root/setup.sh" --test-scenario reliability >/dev/null
[[ ! -e $privileged ]]
grep -Fq "sudo rm -f -- $privileged" "$STUB_LOG"
printf 'ok - rollback deletes validated privileged created files through sudo\n'

# RC-03: a failed restore stops later rows, reports partial work, and records nonzero metadata.
failed_restore="$HOME/dotfiles/.config/hypr/fail-first.conf"
later_restore="$HOME/dotfiles/.config/hypr/fail-later.conf"
printf 'installed first\n' > "$failed_restore"
printf 'installed later\n' > "$later_restore"
printf 'original first\n' > "$fixture/original-first"
printf 'original later\n' > "$fixture/original-later"
restore_id=20010101T000003Z-000003
printf -v restore_rows 'modified\t%s\t%s\t%s\tbackup/first\nmodified\t%s\t%s\t%s\tbackup/later' \
  "$failed_restore" "$(hash_file "$fixture/original-first")" "$(hash_file "$failed_restore")" \
  "$later_restore" "$(hash_file "$fixture/original-later")" "$(hash_file "$later_restore")"
make_run "$restore_id" "$restore_rows"
cp "$fixture/original-first" "$state/runs/$restore_id/backup/first"
cp "$fixture/original-later" "$state/runs/$restore_id/backup/later"
set +e
restore_output=$(PATH="$failure_bin:$PATH" HSS_SHIM_FAIL_MV_DEST="$failed_restore" \
  HSS_RELIABILITY_ACTION=rollback HSS_ROLLBACK_RUN_ID="$restore_id" \
  "$repo_root/setup.sh" --test-scenario reliability 2>&1)
restore_status=$?
set -e
[[ $restore_status -ne 0 ]]
[[ $(<"$failed_restore") == 'installed first' ]]
[[ $(<"$later_restore") == 'installed later' ]]
grep -Fq "mv failure shim refused destination $failed_restore" <<<"$restore_output"
grep -Fq "Rollback failed for $failed_restore after 0 completed change(s); rollback is partial" <<<"$restore_output"
if grep -Fq 'Rollback completed' <<<"$restore_output"; then
  printf 'not ok - failed rollback printed a success message\n' >&2
  exit 1
fi
failure_run=$(cat "$state/latest-run")
grep -Eq '^exit=[1-9][0-9]*$' "$state/runs/$failure_run/meta"
printf 'ok - rollback restore failure stops later writes and records nonzero exit status\n'

# Deletion failures follow the same fail-fast contract.
delete_first="$HOME/dotfiles/.config/hypr/delete-first.conf"
delete_later="$HOME/dotfiles/.config/hypr/delete-later.conf"
printf 'delete first\n' > "$delete_first"
printf 'delete later\n' > "$delete_later"
delete_id=20010101T000004Z-000004
printf -v delete_rows 'created\t%s\t-\t%s\t-\ncreated\t%s\t-\t%s\t-' \
  "$delete_first" "$(hash_file "$delete_first")" "$delete_later" "$(hash_file "$delete_later")"
make_run "$delete_id" "$delete_rows"
set +e
delete_output=$(PATH="$failure_bin:$PATH" HSS_SHIM_FAIL_RM_TARGET="$delete_first" \
  HSS_RELIABILITY_ACTION=rollback HSS_ROLLBACK_RUN_ID="$delete_id" \
  "$repo_root/setup.sh" --test-scenario reliability 2>&1)
delete_status=$?
set -e
[[ $delete_status -ne 0 ]]
[[ -f $delete_first && -f $delete_later ]]
grep -Fq "rm failure shim refused target $delete_first" <<<"$delete_output"
grep -Fq "Rollback failed for $delete_first after 0 completed change(s); rollback is partial" <<<"$delete_output"
delete_run=$(cat "$state/latest-run")
grep -Eq '^exit=[1-9][0-9]*$' "$state/runs/$delete_run/meta"
printf 'ok - rollback deletion failure stops later deletes and records nonzero exit status\n'

# RC-04: generation and rename failures preserve prior manifest/meta state.
old_hash=$(printf old | sha256sum | awk '{print $1}')
new_hash=$(printf new | sha256sum | awk '{print $1}')
state_path="$HOME/dotfiles/.config/hypr/state-update.conf"
printf -v initial_manifest 'created\t%s\t-\t%s\t-' "$state_path" "$old_hash"
for context in manifest meta; do
  for phase in generate rename; do
    fail_awk_suffix=""
    fail_mv_suffix=""
    [[ $context != manifest ]] || state_suffix=/manifest.tsv
    [[ $context != meta ]] || state_suffix=/meta
    [[ $phase != generate ]] || fail_awk_suffix=$state_suffix
    [[ $phase != rename ]] || fail_mv_suffix=$state_suffix
    set +e
    state_output=$(PATH="$failure_bin:$PATH" \
      HSS_SHIM_FAIL_AWK_SUFFIX="$fail_awk_suffix" \
      HSS_SHIM_FAIL_MV_SUFFIX="$fail_mv_suffix" \
      HSS_STATE_UPDATE_KIND="$context" \
      HSS_STATE_INITIAL="$initial_manifest" \
      HSS_STATE_PATH="$state_path" \
      HSS_STATE_AFTER="$new_hash" \
      HSS_RELIABILITY_ACTION=state-update \
      "$repo_root/setup.sh" --test-scenario reliability 2>&1)
    state_status=$?
    set -e
    [[ $state_status -ne 0 ]]
    state_run=$(cat "$state/latest-run")
    if [[ $context == manifest ]]; then
      [[ $(<"$state/runs/$state_run/manifest.tsv") == "$initial_manifest" ]]
    else
      grep -Fq 'HSS_TEST_STATE=old' "$state/runs/$state_run/meta"
      if grep -Fq 'HSS_TEST_STATE=new' "$state/runs/$state_run/meta"; then
        printf 'not ok - failed metadata update replaced old value\n' >&2
        exit 1
      fi
    fi
    if [[ $phase == generate ]]; then
      grep -Fq 'awk failure shim refused input' <<<"$state_output"
    else
      grep -Fq 'mv failure shim refused destination' <<<"$state_output"
    fi
    grep -Fqi "failed to" <<<"$state_output"
  done
done
printf 'ok - manifest and metadata generation/rename failures preserve old state\n'

# RC-05: a required role write failure is visible and prevents later role writes.
app_variables="$HOME/dotfiles/.config/hypr/sources/app_variables.lua"
later_file="$HOME/dotfiles/.config/hypr/sources/environment_variables.lua"
cp "$app_variables" "$fixture/app-before"
cp "$later_file" "$fixture/later-before"
set +e
role_output=$(PATH="$failure_bin:$PATH" HSS_SHIM_FAIL_MV_DEST="$app_variables" \
  "$repo_root/setup.sh" --test-scenario roles 2>&1)
role_status=$?
set -e
[[ $role_status -ne 0 ]]
cmp -s "$fixture/app-before" "$app_variables"
cmp -s "$fixture/later-before" "$later_file"
grep -Fq "mv failure shim refused destination $app_variables" <<<"$role_output"
if grep -Fq 'Configured roles:' <<<"$role_output"; then
  printf 'not ok - failed role configuration printed success\n' >&2
  exit 1
fi
role_run=$(cat "$state/latest-run")
grep -Eq '^exit=[1-9][0-9]*$' "$state/runs/$role_run/meta"
printf 'ok - required role write failure propagates, preserves target, and stops later writes\n'

# RC-06: an accepted final row without a newline must still be restored.
unterminated="$HOME/dotfiles/.config/hypr/unterminated.conf"
printf 'installed unterminated\n' > "$unterminated"
printf 'original unterminated\n' > "$fixture/unterminated-backup"
unterminated_id=20010101T000005Z-000005
printf -v unterminated_row 'modified\t%s\t%s\t%s\tbackup/value' \
  "$unterminated" "$(hash_file "$fixture/unterminated-backup")" "$(hash_file "$unterminated")"
make_run "$unterminated_id" "$unterminated_row" false
cp "$fixture/unterminated-backup" "$state/runs/$unterminated_id/backup/value"
HSS_RELIABILITY_ACTION=rollback HSS_ROLLBACK_RUN_ID="$unterminated_id" \
  "$repo_root/setup.sh" --test-scenario reliability >/dev/null
[[ $(<"$unterminated") == 'original unterminated' ]]
printf 'ok - rollback executes a validated final manifest row without a newline\n'
