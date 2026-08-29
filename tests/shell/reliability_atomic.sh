#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults

target="$HOME/dotfiles/.config/hypr/atomic.conf"
link="$HOME/.config/atomic.conf"
printf 'before\n' > "$target"
chmod 0600 "$target"
ln -s "$target" "$link"
printf 'after\n' > "$fixture/source"
HSS_RELIABILITY_ACTION=atomic HSS_DEST="$link" HSS_SOURCE="$fixture/source" "$repo_root/setup.sh" --test-scenario reliability
[[ -L $link ]]
[[ $(cat "$target") == after ]]
[[ $(stat -c %a "$target") == 600 ]]
run=$(cat "$XDG_STATE_HOME/hyprland-simple-setup/latest-run")
manifest="$XDG_STATE_HOME/hyprland-simple-setup/runs/$run/manifest.tsv"
[[ $(wc -l < "$manifest") -eq 1 ]]
grep -q $'^symlink-target\t' "$manifest"
[[ $(cut -f2 "$manifest") == "$target" ]]
[[ $(sha256sum "$target" | cut -d' ' -f1) == "$(cut -f4 "$manifest")" ]]
printf 'ok - symlink-preserving atomic write keeps mode and truthful manifest\n'

mkdir -p "$HOME/dotfiles/.config/nested"
ln -s "$HOME/dotfiles/.config/nested" "$HOME/.config/nested"
printf 'nested before\n' > "$HOME/dotfiles/.config/nested/value.conf"
printf 'nested after\n' > "$fixture/nested-source"
HSS_RELIABILITY_ACTION=atomic HSS_DEST="$HOME/.config/nested/value.conf" HSS_SOURCE="$fixture/nested-source" "$repo_root/setup.sh" --test-scenario reliability
nested_run=$(cat "$XDG_STATE_HOME/hyprland-simple-setup/latest-run")
grep -q $'^symlink-target\t' "$XDG_STATE_HOME/hyprland-simple-setup/runs/$nested_run/manifest.tsv"

outside="$fixture/outside.conf"
printf 'outside\n' > "$outside"
ln -s "$outside" "$HOME/.config/escape.conf"
set +e
escape_output=$(HSS_RELIABILITY_ACTION=atomic HSS_DEST="$HOME/.config/escape.conf" HSS_SOURCE="$fixture/source" "$repo_root/setup.sh" --test-scenario reliability 2>&1)
escape_status=$?
set -e
[[ $escape_status -ne 0 ]]
grep -q 'outside approved roots' <<< "$escape_output"
[[ $(cat "$outside") == outside ]]
printf 'ok - nested symlinks are classified and external symlink targets are refused\n'

created="$HOME/dotfiles/.config/hypr/new.conf"
printf 'new\n' > "$fixture/new-source"
chmod 0600 "$fixture/new-source"
HSS_RELIABILITY_ACTION=atomic HSS_DEST="$created" HSS_SOURCE="$fixture/new-source" "$repo_root/setup.sh" --test-scenario reliability
[[ $(stat -c %a "$created") == 644 ]]
[[ $(stat -c %u "$created") == $(id -u) ]]
printf 'ok - new user files default to invoking-user ownership and mode 0644\n'

export HSS_TEST_ETC_ROOT="$fixture/etc"
mkdir -p "$HSS_TEST_ETC_ROOT"
printf '[options]\n' > "$HSS_TEST_ETC_ROOT/pacman.conf"
printf '[options]\nColor\n' > "$fixture/etc-source"
: > "$STUB_LOG"
HSS_RELIABILITY_ACTION=atomic HSS_DEST="$HSS_TEST_ETC_ROOT/pacman.conf" HSS_SOURCE="$fixture/etc-source" "$repo_root/setup.sh" --test-scenario reliability
grep -q '^Color$' "$HSS_TEST_ETC_ROOT/pacman.conf"
grep -q '^sudo .*mktemp' "$STUB_LOG"
printf 'ok - privileged atomic path uses sudo stubs inside isolated test etc root\n'

before=$(find "$HOME" -type f -print0 | sort -z | xargs -0 -r sha256sum | sha256sum)
dry_output=$(DRY_RUN=true HSS_RELIABILITY_ACTION=dry-record HSS_DEST="$HOME/dotfiles/.config/hypr/sources/app_variables.conf" "$repo_root/setup.sh" --test-scenario reliability 2>&1)
after=$(find "$HOME" -type f -print0 | sort -z | xargs -0 -r sha256sum | sha256sum)
[[ $before == "$after" ]]
grep -Fq "$HOME/dotfiles/.config/hypr/sources/app_variables.conf" <<< "$dry_output"
printf 'ok - dry run changes only state and reports destination with reason\n'

first=$(cat "$XDG_STATE_HOME/hyprland-simple-setup/latest-run")
HSS_RELIABILITY_ACTION=atomic HSS_DEST="$target" HSS_SOURCE="$fixture/source" "$repo_root/setup.sh" --test-scenario reliability
second=$(cat "$XDG_STATE_HOME/hyprland-simple-setup/latest-run")
[[ $first != "$second" ]]
[[ -d $XDG_STATE_HOME/hyprland-simple-setup/runs/$first && -d $XDG_STATE_HOME/hyprland-simple-setup/runs/$second ]]
printf 'ok - independent runs use isolated run directories\n'
