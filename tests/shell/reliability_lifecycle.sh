#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults

holder_out="$fixture/holder.out"
HSS_RELIABILITY_ACTION=lock-hold HSS_HOLD_SECONDS=3 "$repo_root/setup.sh" --test-scenario reliability >"$holder_out" 2>&1 &
holder=$!
for _ in {1..50}; do grep -q 'holder pid=' "$holder_out" 2>/dev/null && break; sleep 0.05; done
set +e
blocked=$(HSS_RELIABILITY_ACTION=lock-hold HSS_HOLD_SECONDS=0 "$repo_root/setup.sh" --test-scenario reliability 2>&1)
blocked_status=$?
set -e
[[ $blocked_status -eq 2 ]]
grep -Fq "pid $holder" <<< "$blocked"
wait "$holder"
printf 'ok - lock contention exits 2 and reports holder pid\n'

signal_out="$fixture/signal.out"
set +e
HSS_RELIABILITY_ACTION=temp-wait HSS_HOLD_SECONDS=30 timeout --signal=INT 1 "$repo_root/setup.sh" --test-scenario reliability >"$signal_out" 2>&1
signal_status=$?
set -e
[[ $signal_status -eq 124 ]]
temp_path=$(head -n1 "$signal_out")
[[ -n $temp_path && ! -e $temp_path ]]
run_id=$(basename "$(dirname "$(dirname "$temp_path")")")
grep -q '^exit=130$' "$XDG_STATE_HOME/hyprland-simple-setup/runs/$run_id/meta"
printf 'ok - SIGINT re-raises and removes run temporary files\n'

term_out="$fixture/term.out"
set +e
HSS_RELIABILITY_ACTION=temp-wait HSS_HOLD_SECONDS=30 timeout --signal=TERM 1 "$repo_root/setup.sh" --test-scenario reliability >"$term_out" 2>&1
term_status=$?
set -e
[[ $term_status -eq 124 ]]
term_path=$(head -n1 "$term_out")
[[ -n $term_path && ! -e $term_path ]]
term_run=$(basename "$(dirname "$(dirname "$term_path")")")
grep -q '^exit=143$' "$XDG_STATE_HOME/hyprland-simple-setup/runs/$term_run/meta"
printf 'ok - SIGTERM re-raises and removes run temporary files\n'

keepalive_out="$fixture/keepalive.out"
HSS_RELIABILITY_ACTION=keepalive HSS_KEEPALIVE_INTERVAL=1 HSS_HOLD_SECONDS=1 "$repo_root/setup.sh" --test-scenario reliability >"$keepalive_out" 2>&1
keepalive_pid=$(head -n1 "$keepalive_out")
if kill -0 "$keepalive_pid" 2>/dev/null; then
  printf 'not ok - keepalive still alive: %s\n' "$keepalive_pid"
  exit 1
fi
printf 'ok - sudo keepalive is gone after exit\n'

password_keepalive_out="$fixture/password-keepalive.out"
sudo_cache="$fixture/sudo-cache"
: > "$STUB_LOG"
SUDO_PASSWORD='tui-provided-password' \
STUB_SUDO_REQUIRE_PASSWORD=1 \
STUB_SUDO_EXPECTED_PASSWORD='tui-provided-password' \
STUB_SUDO_CACHE_FILE="$sudo_cache" \
HSS_RELIABILITY_ACTION=keepalive \
HSS_KEEPALIVE_INTERVAL=1 \
HSS_HOLD_SECONDS=1 \
  "$repo_root/setup.sh" --test-scenario reliability >"$password_keepalive_out" 2>&1
password_keepalive_pid=$(head -n1 "$password_keepalive_out")
[[ -f $sudo_cache ]]
grep -Fq 'sudo -n -v' "$STUB_LOG"
grep -Fq "sudo -S -p '' -v" "$STUB_LOG"
if grep -Fq 'tui-provided-password' "$STUB_LOG"; then
  printf 'not ok - password leaked into sudo command log\n'
  exit 1
fi
if kill -0 "$password_keepalive_pid" 2>/dev/null; then
  printf 'not ok - password keepalive still alive: %s\n' "$password_keepalive_pid"
  exit 1
fi
printf 'ok - TUI password seeds and maintains unattended sudo credentials\n'

nested_sudo_out="$fixture/nested-sudo.out"
nested_sudo_cache="$fixture/nested-sudo-cache"
: > "$STUB_LOG"
SUDO_PASSWORD='tui-provided-password' \
STUB_SUDO_REQUIRE_PASSWORD=1 \
STUB_SUDO_EXPECTED_PASSWORD='tui-provided-password' \
STUB_SUDO_CACHE_FILE="$nested_sudo_cache" \
HSS_RELIABILITY_ACTION=nested-sudo \
  "$repo_root/setup.sh" --test-scenario reliability >"$nested_sudo_out" 2>&1
grep -Fq "sudo -S -p '' -n true" "$STUB_LOG"
if grep -Fq 'tui-provided-password' "$STUB_LOG"; then
  printf 'not ok - nested sudo leaked the password into the command log\n'
  exit 1
fi
printf 'ok - nested Bash tools inherit password-backed sudo\n'

yay_checkout="$fixture/existing-yay"
mkdir -p "$yay_checkout"
git -C "$yay_checkout" init -q
git -C "$yay_checkout" config user.name test
git -C "$yay_checkout" config user.email test@example.invalid
printf 'pkgname=yay\npkgver=1\npkgrel=1\narch=(any)\n' > "$yay_checkout/PKGBUILD"
git -C "$yay_checkout" add PKGBUILD
git -C "$yay_checkout" commit -qm initial
git -C "$yay_checkout" remote add origin https://aur.archlinux.org/yay.git
yay_bootstrap_out="$fixture/yay-bootstrap.out"
yay_sudo_cache="$fixture/yay-sudo-cache"
: > "$STUB_LOG"
SUDO_PASSWORD='tui-provided-password' \
STUB_SUDO_REQUIRE_PASSWORD=1 \
STUB_SUDO_EXPECTED_PASSWORD='tui-provided-password' \
STUB_SUDO_CACHE_FILE="$yay_sudo_cache" \
HSS_YAY_DIR="$yay_checkout" \
HSS_RELIABILITY_ACTION=yay-bootstrap \
  "$repo_root/setup.sh" --test-scenario reliability >"$yay_bootstrap_out" 2>&1
grep -Fq "Reusing existing yay checkout: $yay_checkout" "$yay_bootstrap_out"
grep -Fq "makepkg cwd=$yay_checkout" "$STUB_LOG"
grep -Fq -- '--config' "$STUB_LOG"
grep -Fq 'makepkg-auth=' "$STUB_LOG"
grep -Fq "sudo -S -p '' -- /usr/bin/true" "$STUB_LOG"
if grep -Fq 'tui-provided-password' "$STUB_LOG"; then
  printf 'not ok - yay bootstrap leaked the password into the command log\n'
  exit 1
fi
printf 'ok - yay bootstrap reuses checkout and supplies explicit makepkg authentication\n'

filepicker_config_dir="$HOME/.config/xdg-desktop-portal"
filepicker_desktop_dir="$HOME/.local/share/applications"
mkdir -p "$filepicker_config_dir" "$filepicker_desktop_dir"
printf '%s\n' \
  '[preferred]' \
  'default = hyprland;gtk' \
  'org.freedesktop.impl.portal.FileChooser = kde' > "$filepicker_config_dir/hyprland-portals.conf"
printf '%s\n' \
  '[Desktop Entry]' \
  'Type=Application' \
  'Name=Visual Studio Code' \
  'Exec=code %F' \
  'MimeType=text/plain;application/x-shellscript;' > "$filepicker_desktop_dir/visual-studio-code.desktop"
update-desktop-database "$filepicker_desktop_dir"
HSS_RELIABILITY_ACTION=filepicker \
  "$repo_root/setup.sh" --test-scenario reliability >"$fixture/filepicker.out" 2>&1
grep -Fq 'org.freedesktop.impl.portal.FileChooser = gtk' "$filepicker_config_dir/hyprland-portals.conf"
if grep -Fq 'org.freedesktop.impl.portal.FileChooser = kde' "$filepicker_config_dir/hyprland-portals.conf"; then
  printf 'not ok - file chooser still selects the KDE backend\n'
  exit 1
fi
[[ $(xdg-mime query default text/plain) == visual-studio-code.desktop ]]
[[ $(xdg-mime query default application/x-shellscript) == visual-studio-code.desktop ]]
if grep -Fq 'applications.menu' "$STUB_LOG"; then
  printf 'not ok - file chooser setup still mutates the system application menu\n'
  exit 1
fi
printf 'ok - GTK file chooser and selected editor MIME defaults are configured without a live Hyprland session\n'

managed_wallpaper_script="$HOME/dotfiles/.config/hypr/scripts/change_wallpaper.sh"
printf 'outdated managed script\n' > "$managed_wallpaper_script"
chmod 0600 "$managed_wallpaper_script"
HSS_RELIABILITY_ACTION=sync-managed \
  "$repo_root/setup.sh" --test-scenario reliability >"$fixture/sync-managed.out" 2>&1
cmp -s "$repo_root/dotfiles/.config/hypr/scripts/change_wallpaper.sh" "$managed_wallpaper_script"
[[ -x $managed_wallpaper_script ]]
printf 'ok - existing dotfiles receive installer-managed wallpaper startup fixes\n'

default_config_dir="$HOME/.config/hypr/monitor-default-test"
default_monitors="$default_config_dir/monitors.lua"
default_wallpaper="$default_config_dir/change_wallpaper.lua"
wallpaper_dir_literal="\$HOME/Pictures/Wallpapers"
mkdir -p "$default_config_dir"
printf '%s\n' '-- no explicit monitor rules' > "$default_monitors"
printf '%s\n' 'return {' "    wallpaper_dir = \"$wallpaper_dir_literal\"," '    monitors = {},' '}' > "$default_wallpaper"
HSS_MONITORS_FILE="$default_monitors" \
HSS_WALLPAPER_FILE="$default_wallpaper" \
HSS_RELIABILITY_ACTION=monitor-defaults \
  "$repo_root/setup.sh" --test-scenario reliability >"$fixture/monitor-defaults.out" 2>&1
grep -Fq 'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })' "$default_monitors"
grep -Fq '    monitors = {},' "$default_wallpaper"
grep -Fq 'using the hyprpaper fallback target' "$fixture/monitor-defaults.out"
printf 'ok - missing monitor choices install Hyprland and hyprpaper defaults\n'

wallpaper_home="$fixture/wallpaper-home"
wallpaper_bin="$fixture/wallpaper-bin"
wallpaper_stub_log="$fixture/wallpaper-stub.log"
mkdir -p "$wallpaper_home/.config/hypr/sources_specific" "$wallpaper_home/Pictures/Wallpapers" "$wallpaper_bin"
printf 'wallpaper fixture\n' > "$wallpaper_home/Pictures/Wallpapers/default.png"
printf '%s\n' \
  'return {' \
  "    wallpaper_dir = \"$wallpaper_dir_literal\"," \
  '    monitors = {},' \
  '}' > "$wallpaper_home/.config/hypr/sources_specific/change_wallpaper.lua"
cat > "$wallpaper_bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == monitors ]]; then
  printf 'Monitor eDP-1 (ID 0):\n'
  exit 0
fi
if [[ ${1:-} == hyprpaper && ${2:-} == wallpaper ]]; then
  if [[ $# -eq 2 ]]; then
    printf 'parser diagnostics are not an IPC readiness probe\n' >&2
    exit 77
  fi
  printf '%s\n' "$3" >> "${WALLPAPER_STUB_LOG:?}"
  exit 0
fi
exit 1
EOF
cat > "$wallpaper_bin/hyprpaper" <<'EOF'
#!/usr/bin/env bash
touch "${HYPRPAPER_RUNNING_FILE:?}"
printf 'start hyprpaper\n' >> "${WALLPAPER_STUB_LOG:?}"
EOF
cat > "$wallpaper_bin/pgrep" <<'EOF'
#!/usr/bin/env bash
if [[ -z ${HYPRPAPER_RUNNING_FILE:-} ]]; then
  exit 0
fi
[[ -e $HYPRPAPER_RUNNING_FILE ]]
EOF
cat > "$wallpaper_bin/pkill" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$wallpaper_bin/hyprctl" "$wallpaper_bin/hyprpaper" "$wallpaper_bin/pgrep" "$wallpaper_bin/pkill"
: > "$wallpaper_stub_log"
HOME="$wallpaper_home" \
WALLPAPER_CHANGE_STAMP="$fixture/wallpaper-change-ran" \
WALLPAPER_STUB_LOG="$wallpaper_stub_log" \
HYPRPAPER_RUNNING_FILE="$fixture/hyprpaper-running" \
PATH="$wallpaper_bin:$PATH" \
  "$repo_root/dotfiles/.config/hypr/scripts/change_wallpaper.sh" >"$fixture/wallpaper-default.out" 2>&1
HOME="$wallpaper_home" \
WALLPAPER_CHANGE_STAMP="$fixture/wallpaper-change-ran-manual" \
WALLPAPER_STUB_LOG="$wallpaper_stub_log" \
HYPRPAPER_RUNNING_FILE="$fixture/hyprpaper-running" \
PATH="$wallpaper_bin:$PATH" \
  "$repo_root/dotfiles/.config/hypr/scripts/change_wallpaper.sh" >"$fixture/wallpaper-manual.out" 2>&1
grep -Fq 'No explicit monitors configured; using the hyprpaper fallback target.' "$fixture/wallpaper-default.out"
grep -Fq 'No explicit monitors configured; using the hyprpaper fallback target.' "$fixture/wallpaper-manual.out"
[[ $(grep -Fxc 'start hyprpaper' "$wallpaper_stub_log") -eq 1 ]]
grep -Eq '^, .*/default[.]png, cover$' "$wallpaper_stub_log"
if grep -Fq 'MONITORS array is empty' "$fixture/wallpaper-default.out"; then
  printf 'not ok - empty monitor list still fails wallpaper startup\n'
  exit 1
fi
expected_wallpaper="$wallpaper_home/Pictures/Wallpapers/default.png"
[[ $(readlink -- "$wallpaper_home/.cache/wlogout/current-wallpaper") == "$expected_wallpaper" ]]
printf 'ok - wallpaper script works at autostart and on a manual rerun without restarting hyprpaper\n'

cat > "$wallpaper_bin/wlogout" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${WLOGOUT_STUB_LOG:?}"
EOF
chmod +x "$wallpaper_bin/wlogout"
mkdir -p "$wallpaper_home/.config/wlogout"
cp "$repo_root/dotfiles/.config/wlogout/style.css" "$wallpaper_home/.config/wlogout/style.css"
WLOGOUT_STUB_LOG="$fixture/wlogout-stub.log" \
HOME="$wallpaper_home" \
PATH="$wallpaper_bin:$PATH" \
  "$repo_root/dotfiles/.config/waybar/scripts/launch_power_screen.sh"
[[ $(readlink -- "$wallpaper_home/.cache/wlogout/current-wallpaper") == "$expected_wallpaper" ]]
grep -Fq -- "--protocol layer-shell --css $wallpaper_home/.config/wlogout/style.css" "$fixture/wlogout-stub.log"
grep -Fq 'background-image: url("../../.cache/wlogout/current-wallpaper")' "$wallpaper_home/.config/wlogout/style.css"
if grep -Fq 'hyprpaper listactive' "$repo_root/dotfiles/.config/waybar/scripts/launch_power_screen.sh"; then
  printf 'not ok - wlogout launcher still relies on removed hyprpaper listactive IPC\n'
  exit 1
fi
printf 'ok - wlogout consumes the wallpaper cache without removed IPC commands\n'

package_bin="$fixture/package-bin"
mkdir -p "$package_bin"
cat > "$package_bin/pacman" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -Qnq) printf '%s\n' base linux fastfetch ;;
  -Qmq) printf '%s\n' aur-one aur-two ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$package_bin/pacman"
package_output=$(PATH="$package_bin:$PATH" "$repo_root/dotfiles/.config/fastfetch/package-count.sh")
[[ $package_output == '5 (pacman: 3, AUR/foreign: 2)' ]]
grep -Fq '"text": "~/.config/fastfetch/package-count.sh"' "$repo_root/dotfiles/.config/fastfetch/config.jsonc"
if grep -Fq '"format": "{1} (pacman: {2})"' "$repo_root/dotfiles/.config/fastfetch/config.jsonc"; then
  printf 'not ok - Fastfetch still uses unstable numeric package placeholders\n'
  exit 1
fi
printf 'ok - Fastfetch reports native and AUR/foreign package counts\n'

run_once_dir="$fixture/run-once"
run_once_log="$run_once_dir/runs.log"
run_once_ready="$run_once_dir/ready"
mkdir -p "$run_once_dir/runtime"
cat > "$run_once_dir/hold.sh" <<'EOF'
#!/usr/bin/env bash
printf 'run\n' >> "${RUN_ONCE_LOG:?}"
touch "${RUN_ONCE_READY:?}"
sleep 1
EOF
chmod +x "$run_once_dir/hold.sh"
RUN_ONCE_LOG="$run_once_log" RUN_ONCE_READY="$run_once_ready" \
XDG_RUNTIME_DIR="$run_once_dir/runtime" HYPRLAND_INSTANCE_SIGNATURE=test-instance \
  "$repo_root/dotfiles/.config/hypr/scripts/run_once.sh" kitty-layout "$run_once_dir/hold.sh" &
run_once_pid=$!
for _ in {1..50}; do
  [[ -e $run_once_ready ]] && break
  sleep 0.02
done
[[ -e $run_once_ready ]]
RUN_ONCE_LOG="$run_once_log" RUN_ONCE_READY="$run_once_ready" \
XDG_RUNTIME_DIR="$run_once_dir/runtime" HYPRLAND_INSTANCE_SIGNATURE=test-instance \
  "$repo_root/dotfiles/.config/hypr/scripts/run_once.sh" kitty-layout "$run_once_dir/hold.sh"
wait "$run_once_pid"
[[ $(grep -c '^run$' "$run_once_log") -eq 1 ]]
printf 'ok - per-session run-once lock suppresses a duplicate Kitty layout launch\n'
