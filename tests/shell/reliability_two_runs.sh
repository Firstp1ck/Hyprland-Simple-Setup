#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults
ROLE_TERMINAL=kitty "$repo_root/setup.sh" --test-scenario roles >/dev/null
first=$(cat "$XDG_STATE_HOME/hyprland-simple-setup/latest-run")
ROLE_TERMINAL=alacritty ROLE_BROWSER=firefox "$repo_root/setup.sh" --test-scenario roles >/dev/null
second=$(cat "$XDG_STATE_HOME/hyprland-simple-setup/latest-run")
[[ $first != "$second" ]]
for run in "$first" "$second"; do
  dir="$XDG_STATE_HOME/hyprland-simple-setup/runs/$run"
  [[ -s $dir/manifest.tsv ]]
  grep -q '^end=' "$dir/meta"
  grep -q '^exit=0$' "$dir/meta"
  windows="$HOME/dotfiles/.config/hypr/sources/windows_and_workspaces.conf"
  [[ $(awk -F '\t' -v path="$windows" '$2 == path {count++} END {print count+0}' "$dir/manifest.tsv") -eq 1 ]]
done
grep -q "^\$terminal = 'alacritty'" "$HOME/dotfiles/.config/hypr/sources/app_variables.conf"
grep -q "^\$browser = 'firefox'" "$HOME/dotfiles/.config/hypr/sources/app_variables.conf"
grep -q 'sudo -n chsh -s /usr/bin/fish -- ' "$STUB_LOG"
second_manifest="$XDG_STATE_HOME/hyprland-simple-setup/runs/$second/manifest.tsv"
windows="$HOME/dotfiles/.config/hypr/sources/windows_and_workspaces.conf"
IFS=$'\t' read -r _ _ before_hash after_hash backup_rel < <(awk -F '\t' -v path="$windows" '$2 == path' "$second_manifest")
[[ $(sha256sum "$XDG_STATE_HOME/hyprland-simple-setup/runs/$second/$backup_rel" | cut -d' ' -f1) == "$before_hash" ]]
[[ $(sha256sum "$windows" | cut -d' ' -f1) == "$after_hash" ]]

home_before=$(find "$HOME" -type f -print0 | sort -z | xargs -0 -r sha256sum | sha256sum)
dry_output=$(DRY_RUN=true ROLE_TERMINAL=ghostty "$repo_root/setup.sh" --test-scenario roles 2>&1)
home_after=$(find "$HOME" -type f -print0 | sort -z | xargs -0 -r sha256sum | sha256sum)
[[ $home_before == "$home_after" ]]
grep -Fq "$HOME/dotfiles/.config/hypr/sources/app_variables.conf" <<< "$dry_output"

list_output=$("$repo_root/setup.sh" --list-runs)
grep -q "$first" <<< "$list_output"
grep -q "$second" <<< "$list_output"
printf 'ok - consecutive role runs are isolated and the second selection wins\n'
