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
DRY_RUN=true "$repo_root/setup.sh" --test-scenario roles >/dev/null 2>&1
[[ $(<"$STUB_LOGIN_SHELL_FILE") == /bin/bash ]]
"$repo_root/setup.sh" --test-scenario roles >/dev/null 2>&1
grep -Fq "chsh -s /usr/bin/zsh --" "$STUB_LOG"
[[ $(<"$STUB_LOGIN_SHELL_FILE") == /usr/bin/zsh ]]
printf 'ok - shell dry-run is non-mutating and a real run verifies the resulting login shell\n'

enable_sddm_line=$(grep -n '^[[:space:]]*enable_sddm$' "$repo_root/setup.sh" | head -n1 | cut -d: -f1)
configure_sddm_theme_line=$(grep -n '^[[:space:]]*configure_sddm_theme$' "$repo_root/setup.sh" | head -n1 | cut -d: -f1)
[[ -n $enable_sddm_line && -n $configure_sddm_theme_line ]]
(( enable_sddm_line < configure_sddm_theme_line ))
printf 'ok - SDDM is enabled before its theme is configured\n'

# Reproduce a previous installer run that enabled both terminal layouts, then
# verify the reconciliation keeps only the selected Kitty session active.
for root in sources sources_example; do
  autostart="$HOME/dotfiles/.config/hypr/$root/autostart.lua"
  sed -i 's|^    -- hl.exec_cmd("kitty -e zellij|    hl.exec_cmd("kitty -e zellij|' "$autostart"
  sed -i '/hl.exec_cmd("sleep 1; " .. apps.hyprscripts .. "\/change_wallpaper.sh")/d' "$autostart"
  sed -i 's|^    hl.exec_cmd("hyprpaper")$|    hl.exec_cmd(apps.hyprscripts .. "/change_wallpaper.sh")|' "$autostart"
done
HSS_RELIABILITY_ACTION=autostart-extras \
  "$repo_root/setup.sh" --test-scenario reliability >/dev/null 2>&1
for root in sources sources_example; do
  autostart="$HOME/dotfiles/.config/hypr/$root/autostart.lua"
  [[ $(grep -Fxc '    hl.exec_cmd("hyprpaper")' "$autostart") -eq 1 ]]
  [[ $(grep -Fxc '    hl.exec_cmd("sleep 1; " .. apps.hyprscripts .. "/change_wallpaper.sh")' "$autostart") -eq 1 ]]
  [[ $(grep -Fxc '    hl.exec_cmd(apps.hyprscripts .. "/change_wallpaper.sh")' "$autostart") -eq 0 ]]
  [[ $(grep -Fxc '    hl.exec_cmd(apps.hyprscripts .. "/run_once.sh kitty-layout kitty --session ~/.config/kitty/my_layout.conf", { workspace = "3 silent" })' "$autostart") -eq 1 ]]
  [[ $(grep -Fxc '    hl.exec_cmd("kitty -e zellij -l ~/.config/zellij/layouts/sysmon.kdl", { workspace = "3 silent" })' "$autostart") -eq 0 ]]
done
printf 'ok - Kitty autostart reconciliation disables the conflicting Zellij window\n'

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
  app_variables="$HOME/dotfiles/.config/hypr/$root/app_variables.lua"
  keybindings="$HOME/dotfiles/.config/hypr/$root/keybindings.lua"
  windows="$HOME/dotfiles/.config/hypr/$root/windows_and_workspaces.lua"
  environment="$HOME/dotfiles/.config/hypr/$root/environment_variables.lua"
  autostart="$HOME/dotfiles/.config/hypr/$root/autostart.lua"

  assert_count 1 '^[[:space:]]*terminal[[:space:]]*=' "$app_variables" "$root terminal assignment"
  assert_count 1 '^[[:space:]]*menu[[:space:]]*=' "$app_variables" "$root launcher assignment"
  assert_count 1 '^[[:space:]]*browser[[:space:]]*=' "$app_variables" "$root browser assignment"
  assert_count 1 '^[[:space:]]*editor[[:space:]]*=' "$app_variables" "$root editor assignment"
  assert_count 1 '^[[:space:]]*editor[[:space:]]*=[[:space:]]*"zeditor",$' "$app_variables" "$root Zed executable"
  assert_count 1 '^bind\(main_mod \.\. " \+ SPACE",' "$keybindings" "$root Open Menu binding"
  assert_count 1 '^window_rule\("vivaldi-stable", \{ workspace = "2 silent" \}\) -- hss-role:browser-workspace$' "$windows" "$root selected browser rule"
  assert_count 1 'hss-role:browser-workspace$' "$windows" "$root browser role rule total"
  assert_count 1 '^hl\.layer_rule\(\{ match = \{ namespace = "rofi" \}, dim_around = true \}\) -- hss-role:launcher-layer$' "$windows" "$root selected launcher layer rule"
  assert_count 1 'hss-role:launcher-layer$' "$windows" "$root launcher layer rule total"
  assert_count 1 '^[[:space:]]*hl\.exec_cmd\("hyprpaper"\)$' "$autostart" "$root hyprpaper startup declaration"
  assert_count 1 '^[[:space:]]*hl\.exec_cmd\("sleep 1; " \.\. apps\.hyprscripts \.\. "/change_wallpaper\.sh"\)$' "$autostart" "$root delayed wallpaper application"
  assert_count 1 'run_once\.sh kitty-layout kitty --session ~/.config/kitty/my_layout\.conf' "$autostart" "$root single-instance Kitty session declaration"
  assert_count 0 '^[[:space:]]*hl\.exec_cmd\("kitty -e zellij ' "$autostart" "$root conflicting Kitty/Zellij autostart"
  assert_count 1 '^window_rule\("xwaylandvideobridge", {' "$windows" "$root XWayland video bridge rule"
  grep -Fq '    float = true,' "$windows"
  grep -Fq '    max_size = { 1, 1 },' "$windows"
  grep -Fq '    no_initial_focus = true,' "$windows"
  if grep -Eq 'XDG_MENU_PREFIX|XDG_DATA_DIRS' "$environment"; then
    printf 'not ok - %s overrides XDG application discovery paths\n' "$root"
    exit 1
  fi
  for class in hss-scratchpad hss-notes hss-clipboard; do
    assert_count 1 "^window_rule\\(\"${class}\"," "$windows" "$root stable $class rule"
  done
  assert_count 1 '^window_rule\("org\.kde\.merkuro\.calendar",' "$windows" "$root Merkuro calendar rule"
done

jq -e '.roles.gui_editor.executable == "zeditor" and .roles.gui_editor.editor_bin == "zeditor"' \
  "$HOME/dotfiles/.config/hypr/roles.json" >/dev/null

fish_config="$HOME/dotfiles/.config/fish/conf.d/01-env.fish"
assert_count 1 '^set -gx MENU_DMENU "rofi -dmenu"$' "$fish_config" "valid Fish MENU_DMENU mirror"
fish --no-execute "$fish_config"

waybar="$HOME/dotfiles/.config/waybar/config.jsonc"
assert_count 1 "\"on-click\": \"\\\$HOME/.config/hypr/scripts/menu_exec.sh --toggle\"" "$waybar" "Waybar launcher wrapper"
assert_count 1 "\"drun\": \"\\\$HOME/.config/hypr/scripts/menu_exec.sh\"" "$waybar" "Waybar dmenu wrapper"
assert_count 1 '"hss-scratchpad"' "$waybar" "Waybar scratchpad ignore"
assert_count 1 '"hss-clipboard"' "$waybar" "Waybar clipboard ignore"
assert_count 1 'Left click: open Merkuro Calendar' "$waybar" "Waybar calendar tooltip"
assert_count 1 "\"on-click\": \"\\\$HOME/.config/hypr/scripts/float_calendar.sh\"" "$waybar" "Waybar calendar launcher"

calendar="$HOME/dotfiles/.config/hypr/scripts/float_calendar.sh"
assert_count 1 'org\\\.kde\\\.merkuro\\\.calendar' "$calendar" "Merkuro window class"
assert_count 1 '^    -- merkuro-calendar$' "$calendar" "Merkuro executable"
assert_count 0 'calcurse' "$calendar" "removed Calcurse launcher"

pypr="$HOME/dotfiles/.config/pypr/config.toml"
assert_count 1 '^command = "~/.config/hypr/scripts/term_exec.sh --app-id hss-scratchpad --title Scratchpad -- bash"$' "$pypr" "Pyprland terminal wrapper"
assert_count 1 '^class = "hss-scratchpad"$' "$pypr" "Pyprland stable class"

hyprlock="$HOME/dotfiles/.config/hypr/hyprlock.conf"
assert_count 1 '^[[:space:]]*path = screenshot$' "$hyprlock" "hyprlock screenshot background"
if grep -Fq "path = \$wallpaper" "$hyprlock"; then
  printf 'not ok - hyprlock still uses the wallpaper directory as an image\n'
  exit 1
fi

dry_output=$(DRY_RUN=true "$repo_root/setup.sh" --test-scenario roles 2>&1)
role_dependent_paths=(
  "$HOME/dotfiles/.config/hypr/roles.json"
  "$HOME/.config/hypr/roles.json"
  "$HOME/dotfiles/.config/hypr/sources/app_variables.lua"
  "$HOME/dotfiles/.config/hypr/sources/environment_variables.lua"
  "$HOME/dotfiles/.config/hypr/sources/keybindings.lua"
  "$HOME/dotfiles/.config/hypr/sources/windows_and_workspaces.lua"
  "$HOME/dotfiles/.config/hypr/sources_example/app_variables.lua"
  "$HOME/dotfiles/.config/hypr/sources_example/environment_variables.lua"
  "$HOME/dotfiles/.config/hypr/sources_example/keybindings.lua"
  "$HOME/dotfiles/.config/hypr/sources_example/windows_and_workspaces.lua"
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
