#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"

count=0
while IFS=$'\t' read -r role package; do
  fixture=$(mktemp -d)
  setup_role_fixture "$fixture"
  set_role_defaults
  set_role_value "$role" "$package"

  output=$("$repo_root/setup.sh" --test-scenario roles 2>&1) || {
    printf 'not ok - %s=%s\n%s\n' "$role" "$package" "$output"
    rm -rf "$fixture"
    exit 1
  }
  actual=$(jq -er --arg role "$role" '.roles[$role].package' "$HOME/.config/hypr/roles.json")
  [[ "$actual" == "$package" ]] || { printf 'not ok - roles.json %s\n' "$role"; exit 1; }
  grep -q "^\\\$terminal = " "$HOME/dotfiles/.config/hypr/sources/app_variables.conf"
  grep -q 'sudo -n chsh -s' "$STUB_LOG"

  dry_output=$(DRY_RUN=true "$repo_root/setup.sh" --test-scenario roles 2>&1) || {
    printf 'not ok - dry-run %s=%s\n%s\n' "$role" "$package" "$dry_output"
    rm -rf "$fixture"
    exit 1
  }
  grep -Fq "$HOME/dotfiles/.config/hypr/sources/app_variables.conf" <<< "$dry_output"
  grep -Fq "$HOME/.config/hypr/roles.json" <<< "$dry_output"

  count=$((count + 1))
  printf 'ok - %s=%s\n' "$role" "$package"
  rm -rf "$fixture"
done < <(jq -r '.roles | to_entries[] | .key as $role | .value.options[] | [$role, .package] | @tsv' "$repo_root/packages.json")

[[ $count -eq 22 ]] || { printf 'not ok - expected 22 role cases, got %d\n' "$count"; exit 1; }
printf 'ok - 22 role options exercised in normal and dry-run scenarios\n'
