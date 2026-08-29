#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults

ROLE_BROWSER=unknown-browser
export ROLE_BROWSER
if output=$("$repo_root/setup.sh" --test-scenario roles 2>&1); then
  printf 'not ok - unknown ROLE_BROWSER was accepted\n'
  exit 1
fi
grep -Fq "ROLE_BROWSER has unknown package value" <<< "$output"
printf 'ok - unknown ROLE_BROWSER rejected\n'

set_role_defaults
unset SELECTED_AUR_PACKAGES
if output=$("$repo_root/setup.sh" --test-scenario roles 2>&1); then
  printf 'not ok - mixed SELECTED_* presence was accepted\n'
  exit 1
fi
grep -Fq 'must either both be set or both be absent' <<< "$output"
printf 'ok - mixed SELECTED_* presence rejected\n'

export SELECTED_AUR_PACKAGES=""
set_role_defaults
ROLE_SHELL=zsh
export ROLE_SHELL
"$repo_root/setup.sh" --test-scenario roles >/dev/null 2>&1
grep -Fq "chsh -s /usr/bin/zsh --" "$STUB_LOG"
printf 'ok - chsh receives explicit zsh path and username\n'

: > "$STUB_LOG"
installed="$fixture/installed"
printf '%s\n' kitty fish visual-studio-code-bin neovim wofi > "$installed"
export STUB_INSTALLED=$installed
set_role_defaults
if output=$("$repo_root/setup.sh" --test-scenario roles 2>&1); then
  printf 'not ok - missing selected package was not a hard failure\n'
  exit 1
fi
grep -Fq "zen-browser-bin" <<< "$output"
printf 'ok - pacman -T missing package is reported\n'

assert_count() {
  local expected=$1 pattern=$2 file=$3 description=$4 actual
  actual=$(grep -Ec "$pattern" "$file" || true)
  if [[ "$actual" != "$expected" ]]; then
    printf 'not ok - %s: expected %s, got %s\n' "$description" "$expected" "$actual"
    return 1
  fi
}

rm -rf "$fixture"
fixture=$(mktemp -d)
setup_role_fixture "$fixture"
export ROLE_BROWSER=vivaldi
export ROLE_TERMINAL=ghostty
export ROLE_SHELL=zsh
export ROLE_GUI_EDITOR=zed
export ROLE_TUI_EDITOR=helix
export ROLE_LAUNCHER=rofi

"$repo_root/setup.sh" --test-scenario roles >/dev/null 2>&1
"$repo_root/setup.sh" --test-scenario roles >/dev/null 2>&1

for root in sources sources_example; do
  app_variables="$HOME/dotfiles/.config/hypr/$root/app_variables.conf"
  keybindings="$HOME/dotfiles/.config/hypr/$root/keybindings.conf"
  windows="$HOME/dotfiles/.config/hypr/$root/windows_and_workspaces.conf"

  assert_count 1 "^\\\$terminal[[:space:]]*=" "$app_variables" "$root terminal assignment"
  assert_count 1 "^\\\$menu[[:space:]]*=" "$app_variables" "$root launcher assignment"
  assert_count 1 "^\\\$browser[[:space:]]*=" "$app_variables" "$root browser assignment"
  assert_count 1 "^\\\$editor[[:space:]]*=" "$app_variables" "$root editor assignment"
  assert_count 1 "^bindd = \\\$mainMod, SPACE, Open Menu," "$keybindings" "$root Open Menu binding"
  assert_count 1 '^windowrule = workspace 2 silent, match:class vivaldi-stable$' "$windows" "$root selected browser rule"
  assert_count 1 '^windowrule = workspace 2.*match:class' "$windows" "$root browser role rule total"
  assert_count 1 '^layerrule = dim_around on, match:namespace rofi$' "$windows" "$root selected launcher layer rule"
  assert_count 1 '^layerrule = dim_around on, match:namespace' "$windows" "$root launcher layer rule total"
  for class in hss-scratchpad hss-notes hss-calendar hss-clipboard; do
    assert_count 1 "^windowrule = .*match:class ${class}$" "$windows" "$root stable $class rule"
  done
done

fish_config="$HOME/dotfiles/.config/fish/conf.d/01-env.fish"
assert_count 1 '^set -gx MENU_DMENU "rofi -dmenu"$' "$fish_config" "valid Fish MENU_DMENU mirror"
fish --no-execute "$fish_config"

waybar="$HOME/dotfiles/.config/waybar/config.jsonc"
assert_count 1 "\"on-click\": \"\\\$HOME/.config/hypr/scripts/menu_exec.sh --toggle\"" "$waybar" "Waybar launcher wrapper"
assert_count 1 "\"drun\": \"\\\$HOME/.config/hypr/scripts/menu_exec.sh\"" "$waybar" "Waybar dmenu wrapper"
assert_count 1 '"hss-scratchpad"' "$waybar" "Waybar scratchpad ignore"
assert_count 1 '"hss-clipboard"' "$waybar" "Waybar clipboard ignore"

pypr="$HOME/dotfiles/.config/pypr/config.toml"
assert_count 1 '^command = "~/.config/hypr/scripts/term_exec.sh --app-id hss-scratchpad --title Scratchpad -- bash"$' "$pypr" "Pyprland terminal wrapper"
assert_count 1 '^class = "hss-scratchpad"$' "$pypr" "Pyprland stable class"

dry_output=$(DRY_RUN=true "$repo_root/setup.sh" --test-scenario roles 2>&1)
role_dependent_paths=(
  "$HOME/dotfiles/.config/hypr/roles.json"
  "$HOME/.config/hypr/roles.json"
  "$HOME/dotfiles/.config/hypr/sources/app_variables.conf"
  "$HOME/dotfiles/.config/hypr/sources/environment_variables.conf"
  "$HOME/dotfiles/.config/hypr/sources/keybindings.conf"
  "$HOME/dotfiles/.config/hypr/sources/windows_and_workspaces.conf"
  "$HOME/dotfiles/.config/hypr/sources_example/app_variables.conf"
  "$HOME/dotfiles/.config/hypr/sources_example/environment_variables.conf"
  "$HOME/dotfiles/.config/hypr/sources_example/keybindings.conf"
  "$HOME/dotfiles/.config/hypr/sources_example/windows_and_workspaces.conf"
  "$HOME/dotfiles/.config/fish/conf.d/01-env.fish"
  "$HOME/dotfiles/.config/fish/conf.d/02-aliases.fish"
)
for path in "${role_dependent_paths[@]}"; do
  grep -Fq "$path" <<< "$dry_output" || {
    printf 'not ok - dry-run omitted role-dependent path: %s\n' "$path"
    exit 1
  }
done
if grep -Fq "$waybar" <<< "$dry_output" || grep -Fq "$pypr" <<< "$dry_output"; then
  printf 'not ok - dry-run reported role-independent Waybar or Pyprland config\n'
  exit 1
fi
printf 'ok - repeated non-default role configuration is idempotent\n'
printf 'ok - Fish MENU_DMENU is valid and wrapper configs remain unique\n'
printf 'ok - dry-run reports only truly role-dependent consumer paths\n'
