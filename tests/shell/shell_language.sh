#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"

fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
unset SHELL_LANGUAGE_CHOICE_OVERRIDE FISH_LANGUAGE_CHOICE_OVERRIDE ZDOTDIR

assert_locale() {
  local shell=$1 file=$2 lang=$3 language=$4
  if [[ $shell == fish ]]; then
    grep -Fxq "set -gx LANG \"$lang\"" "$file"
    grep -Fxq "set -gx LANGUAGE \"$language\"" "$file"
    [[ $(grep -c '^set -gx LANG ' "$file") == 1 ]]
    [[ $(grep -c '^set -gx LANGUAGE ' "$file") == 1 ]]
  else
    grep -Fxq "export LANG=\"$lang\"" "$file"
    grep -Fxq "export LANGUAGE=\"$language\"" "$file"
    [[ $(grep -c '^export LANG=' "$file") == 1 ]]
    [[ $(grep -c '^export LANGUAGE=' "$file") == 1 ]]
    bash -n "$file"
  fi
}

# Every shell is exercised as primary and as an additional selection.
for primary in bash fish zsh; do
  setup_role_fixture "$fixture/$primary"
  set_role_defaults
  export ROLE_SHELL=$primary ROLE_SHELL_PACKAGES='bash fish zsh'
  ln -s "$HOME/dotfiles/.bashrc" "$HOME/.bashrc"
  printf '# Keep this user setting\nexport CUSTOM_SETTING=yes\nexport LANG=old\n' > "$HOME/.zshrc"
  case $primary in
    bash) choice=1; lang=de_CH.UTF-8; language=de_CH:en_US ;;
    fish) choice=2; lang=de_DE.UTF-8; language=de_DE:en_US ;;
    zsh) choice=3; lang=en_US.UTF-8; language=en_US:de_CH ;;
  esac
  export SHELL_LANGUAGE_CHOICE_OVERRIDE=$choice
  "$repo_root/setup.sh" --test-scenario roles > "$fixture/output"
  for file in "$HOME/.bashrc" "$HOME/dotfiles/.bashrc"; do
    assert_locale bash "$file" "$lang" "$language"
  done
  for file in "$HOME/.zshrc" "$HOME/dotfiles/.zshrc"; do
    assert_locale zsh "$file" "$lang" "$language"
  done
  for file in "$HOME/.config/fish/conf.d/01-env.fish" "$HOME/dotfiles/.config/fish/conf.d/01-env.fish"; do
    assert_locale fish "$file" "$lang" "$language"
  done
  [[ -L $HOME/.bashrc && -L $HOME/.config/fish ]]
  grep -Fxq 'export CUSTOM_SETTING=yes' "$HOME/.zshrc"
  grep -Fxq '# Keep this user setting' "$HOME/.zshrc"
  printf 'ok - all selected shells receive locale %s with %s primary\n' "$choice" "$primary"
done

# Repeated changes replace rather than accumulate settings.
export SHELL_LANGUAGE_CHOICE_OVERRIDE=' 2 '
"$repo_root/setup.sh" --test-scenario roles > "$fixture/output"
assert_locale bash "$HOME/.bashrc" de_DE.UTF-8 de_DE:en_US
assert_locale fish "$HOME/.config/fish/conf.d/01-env.fish" de_DE.UTF-8 de_DE:en_US
assert_locale zsh "$HOME/.zshrc" de_DE.UTF-8 de_DE:en_US
printf 'ok - repeated locale changes are idempotent and trim whitespace\n'

setup_role_fixture "$fixture/only-bash"
set_role_defaults
export ROLE_SHELL=bash ROLE_SHELL_PACKAGES=bash
unset SHELL_LANGUAGE_CHOICE_OVERRIDE
export FISH_LANGUAGE_CHOICE_OVERRIDE=3
fish_file="$HOME/dotfiles/.config/fish/conf.d/01-env.fish"
fish_locale_before=$(grep '^set -gx LANG' "$fish_file")
"$repo_root/setup.sh" --test-scenario roles > "$fixture/output"
assert_locale bash "$HOME/.bashrc" en_US.UTF-8 en_US:de_CH
[[ $(grep '^set -gx LANG' "$fish_file") == "$fish_locale_before" ]]
[[ ! -e $HOME/.zshrc && ! -e $HOME/dotfiles/.zshrc ]]
printf 'ok - legacy override works and unselected shell locales stay unchanged\n'

export SHELL_LANGUAGE_CHOICE_OVERRIDE=2
"$repo_root/setup.sh" --test-scenario roles > "$fixture/output"
assert_locale bash "$HOME/.bashrc" de_DE.UTF-8 de_DE:en_US
export SHELL_LANGUAGE_CHOICE_OVERRIDE=invalid
"$repo_root/setup.sh" --test-scenario roles > "$fixture/output"
assert_locale bash "$HOME/.bashrc" de_CH.UTF-8 de_CH:en_US
grep -Fq 'Invalid SHELL_LANGUAGE_CHOICE' "$fixture/output"
printf 'ok - generic override takes precedence and invalid choices use the default\n'

setup_role_fixture "$fixture/dry-run"
set_role_defaults
export ROLE_SHELL=zsh ROLE_SHELL_PACKAGES='bash fish zsh' SHELL_LANGUAGE_CHOICE_OVERRIDE=3
before=$(find "$HOME" -type f -exec sha256sum {} + | sort)
DRY_RUN=true "$repo_root/setup.sh" --test-scenario roles > "$fixture/output"
[[ $(find "$HOME" -type f -exec sha256sum {} + | sort) == "$before" ]]
[[ ! -e $HOME/.bashrc && ! -e $HOME/.zshrc && ! -e $HOME/dotfiles/.zshrc ]]
for shell in bash fish zsh; do
  grep -Fq "$shell language" "$fixture/output"
done
printf 'ok - dry-run reports all selected shells without changing files\n'

setup_role_fixture "$fixture/rollback"
set_role_defaults
export ROLE_SHELL=zsh ROLE_SHELL_PACKAGES='bash zsh'
ln -s "$HOME/dotfiles/.bashrc" "$HOME/.bashrc"
bash_before=$(sha256sum < "$HOME/.bashrc")
"$repo_root/setup.sh" --test-scenario roles > "$fixture/output"
state="$XDG_STATE_HOME/hyprland-simple-setup"
run_id=$(<"$state/latest-run")
HSS_RELIABILITY_ACTION=rollback HSS_ROLLBACK_RUN_ID="$run_id" \
  "$repo_root/setup.sh" --test-scenario reliability > "$fixture/output"
[[ -L $HOME/.bashrc && $(sha256sum < "$HOME/.bashrc") == "$bash_before" ]]
[[ ! -e $HOME/.zshrc && ! -e $HOME/dotfiles/.zshrc ]]
printf 'ok - rollback restores Bash through its symlink and removes created Zsh files\n'

outside="$fixture/outside.zshrc"
printf 'keep outside file\n' > "$outside"
ln -s "$outside" "$HOME/.zshrc"
if "$repo_root/setup.sh" --test-scenario roles > "$fixture/output" 2>&1; then
  printf 'not ok - escaping shell config symlink was accepted\n' >&2
  exit 1
fi
grep -Fq 'outside approved roots' "$fixture/output"
[[ $(<"$outside") == 'keep outside file' ]]
printf 'ok - shell configuration refuses symlinks outside approved roots\n'
