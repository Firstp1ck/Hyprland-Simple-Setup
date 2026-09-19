#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"

fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults

# Exercise migration from the pre-role autostart lines, including insertion of
# the previously absent dock marker inside the Hyprland start callback.
for root in sources sources_example; do
  autostart="$HOME/dotfiles/.config/hypr/$root/autostart.lua"
  sed -i \
    -e 's|^    hl.exec_cmd("sleep 1; " .. apps.hyprscripts .. "/role_exec.sh bar") -- hss-role:bar-autostart$|    hl.exec_cmd([[sleep 1; "$HOME/.config/waybar/scripts/waybar_launch.sh"]])|' \
    -e 's|^    hl.exec_cmd("sleep 1; " .. apps.hyprscripts .. "/role_exec.sh notifications") -- hss-role:notification-autostart$|    -- hl.exec_cmd("swaync")|' \
    -e 's| -- hss-role:gui-editor-autostart$||' \
    -e '/hss-role:dock-autostart$/d' \
    "$autostart"
done

fail() { printf 'not ok - %s\n' "$*" >&2; return 1; }

expect_rejected() {
  local expected=$1
  shift
  local output
  if output=$(env "$@" "$repo_root/setup.sh" --test-scenario roles 2>&1); then
    fail "invalid selection was accepted: $expected"
  fi
  grep -Fq "$expected" <<<"$output" || fail "missing rejection message '$expected': $output"
}

export ROLE_BROWSER=chromium
export ROLE_BROWSER_PACKAGES='firefox chromium'
export ROLE_TERMINAL=foot
export ROLE_TERMINAL_PACKAGES='foot konsole'
export ROLE_GUI_EDITOR=
export ROLE_GUI_EDITOR_PACKAGES=
export ROLE_DOCK=
export ROLE_DOCK_PACKAGES=
"$repo_root/setup.sh" --test-scenario roles >/dev/null
roles_file="$HOME/.config/hypr/roles.json"
jq -e '
  .schema_version == 2
  and .roles.browser.package == "chromium"
  and ([.selected.browser[].package] == ["firefox", "chromium"])
  and .roles.terminal.package == "foot"
  and ([.selected.terminal[].package] == ["konsole", "foot"])
  and .roles.gui_editor == null and .selected.gui_editor == []
  and .roles.dock == null and .selected.dock == []
' "$roles_file" >/dev/null
for root in sources sources_example; do
  autostart="$HOME/dotfiles/.config/hypr/$root/autostart.lua"
  grep -Fq '    -- hl.exec_cmd(apps.editor, { workspace = "1 silent" }) -- hss-role:gui-editor-autostart' "$autostart"
  grep -Fq '    -- hl.exec_cmd("sleep 1; " .. apps.hyprscripts .. "/role_exec.sh dock") -- hss-role:dock-autostart' "$autostart"
  end_line=$(grep -n '^end)$' "$autostart" | cut -d: -f1)
  dock_line=$(grep -n 'hss-role:dock-autostart$' "$autostart" | cut -d: -f1)
  ((dock_line < end_line))
done
printf 'ok - multi-membership, primary, and optional None runtime states\n'

expect_rejected "primary 'chromium' is not in ROLE_BROWSER_PACKAGES" \
  ROLE_BROWSER=chromium ROLE_BROWSER_PACKAGES=firefox
expect_rejected "duplicate package 'firefox'" \
  ROLE_BROWSER=firefox ROLE_BROWSER_PACKAGES='firefox firefox'
expect_rejected 'ROLE_NOTIFICATIONS_PACKAGES accepts at most one package' \
  ROLE_NOTIFICATIONS=swaync ROLE_NOTIFICATIONS_PACKAGES='swaync mako'
expect_rejected 'ROLE_BLUETOOTH_PACKAGES accepts at most one package' \
  ROLE_BLUETOOTH=blueman ROLE_BLUETOOTH_PACKAGES='blueman bluetui'
expect_rejected 'ROLE_BLUETOOTH is required and cannot be empty' \
  ROLE_BLUETOOTH= ROLE_BLUETOOTH_PACKAGES=
expect_rejected 'ROLE_BROWSER is required and cannot be empty' \
  ROLE_BROWSER= ROLE_BROWSER_PACKAGES=
expect_rejected "invalid package token 'firefox;'" \
  ROLE_BROWSER=firefox ROLE_BROWSER_PACKAGES='firefox; touch'
if output=$(env -u ROLE_BROWSER ROLE_BROWSER_PACKAGES=firefox \
  "$repo_root/setup.sh" --test-scenario roles 2>&1); then
  fail 'membership list without a primary was accepted'
fi
grep -Fq 'ROLE_BROWSER must be set when ROLE_BROWSER_PACKAGES is nonempty' <<<"$output"
printf 'ok - duplicate, cardinality, required, token, and primary validation\n'

set_role_defaults
export ROLE_BAR=nwg-panel
export ROLE_DOCK=nwg-panel
export ROLE_AUDIO=qastools
"$repo_root/setup.sh" --test-scenario roles >/dev/null
roles_file="$HOME/.config/hypr/roles.json"
jq -e '.roles.bar.package == "nwg-panel" and .roles.bar.args == ["-c", "bar"]
  and .roles.dock.package == "nwg-panel" and .roles.dock.args == ["-c", "dock"]' "$roles_file" >/dev/null
for root in sources sources_example; do
  autostart="$HOME/dotfiles/.config/hypr/$root/autostart.lua"
  [[ $(grep -Fc 'hss-role:bar-autostart' "$autostart") -eq 1 ]]
  [[ $(grep -Fc 'hss-role:dock-autostart' "$autostart") -eq 1 ]]
  [[ $(grep -Fc 'hss-role:notification-autostart' "$autostart") -eq 1 ]]
  ! grep -Eq '^[[:space:]]*hl\.exec_cmd\("swaync"\)|^[[:space:]]*hl\.exec_cmd\("nm-applet' "$autostart"
done
grep -Fq 'class = "qasmixer"' "$HOME/dotfiles/.config/pypr/config.toml"
grep -Fq 'role_exec.sh" notifications' "$HOME/dotfiles/.local/share/dbus-1/services/org.freedesktop.Notifications.service"
printf 'ok - repeated switching keeps one selected daemon/bar/dock action and updates Pyprland\n'

selection_dump=$(bash -c '
  set -e
  source "$1/setup.sh"
  resolve_package_registry
  load_role_selections
  prepare_package_selections
  printf "pacman=%s\n" "${SELECTED_PACMAN_LIST[*]}"
  printf "aur=%s\n" "${SELECTED_AUR_LIST[*]}"
' bash "$repo_root")
[[ $(grep -o '\bnwg-panel\b' <<<"$selection_dump" | wc -l) -eq 1 ]]
! grep -Eq '\bwaybar\b|\bnwg-dock-hyprland\b' <<<"$selection_dump"
grep -Eq '\bnetworkmanager\b' <<<"$selection_dump"
grep -Eq '\bbluez\b' <<<"$selection_dump"
printf 'ok - shared role package is deduplicated and required backends remain independent\n'

bin="$fixture/bin"
log="$fixture/argv.log"
mkdir -p "$bin"
cat > "$bin/argv-stub" <<'STUB'
#!/usr/bin/env bash
{ printf '%s\0' "${0##*/}"; printf '%s\0' "$@"; } > "$WRAPPER_LOG"
STUB
chmod +x "$bin/argv-stub"
for executable in qasmixer foot nvim; do ln -sf "$bin/argv-stub" "$bin/$executable"; done
WRAPPER_LOG="$log" HSS_ROLES_FILE="$roles_file" PATH="$bin:$PATH" \
  "$HOME/dotfiles/.config/hypr/scripts/role_exec.sh" audio 'literal;$(touch nope)' 'space value'
mapfile -d '' argv < "$log"
[[ ${argv[*]} == 'qasmixer literal;$(touch nope) space value' ]]

set_role_defaults
export ROLE_GUI_EDITOR=
export ROLE_GUI_EDITOR_PACKAGES=
export ROLE_TERMINAL=foot
"$repo_root/setup.sh" --test-scenario roles >/dev/null
roles_file="$HOME/.config/hypr/roles.json"
WRAPPER_LOG="$log" HSS_ROLES_FILE="$roles_file" PATH="$bin:$PATH" \
  "$HOME/dotfiles/.config/hypr/scripts/role_exec.sh" gui_editor 'file with spaces;$(touch nope)'
mapfile -d '' argv < "$log"
[[ ${argv[0]} == foot ]]
[[ ${argv[1]} == --app-id=hss-tui_editor ]]
[[ ${argv[2]} == '--title=tui editor' ]]
[[ ${argv[3]} == nvim ]]
[[ ${argv[4]} == 'file with spaces;$(touch nope)' ]]
[[ ! -e $fixture/nope ]]
printf 'ok - role wrappers preserve exact argv and GUI None falls back through foot\n'
