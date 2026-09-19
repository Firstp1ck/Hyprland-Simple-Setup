#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"

fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults
bin="$fixture/bin"
log="$fixture/argv.log"
mkdir -p "$bin"
cat > "$bin/argv-stub" <<'STUB'
#!/usr/bin/env bash
{ printf '%s\0' "${0##*/}"; printf '%s\0' "$@"; } > "$WRAPPER_LOG"
STUB
chmod +x "$bin/argv-stub"
for executable in swaync-client makoctl dunstctl fnottctl; do
  ln -s "$bin/argv-stub" "$bin/$executable"
done

assert_argv() {
  local description=$1
  shift
  local -a actual=()
  mapfile -d '' actual < "$log"
  [[ ${#actual[@]} -eq $# ]] || {
    printf 'not ok - %s argv count: expected %d, got %d\n' "$description" "$#" "${#actual[@]}" >&2
    return 1
  }
  local index=0 expected
  for expected in "$@"; do
    [[ ${actual[$index]} == "$expected" ]] || {
      printf 'not ok - %s argv[%d]: expected %s, got %s\n' "$description" "$index" "$expected" "${actual[$index]}" >&2
      return 1
    }
    index=$((index + 1))
  done
}

run_control() {
  local provider=$1 action=$2
  shift 2
  export ROLE_NOTIFICATIONS=$provider
  unset ROLE_NOTIFICATIONS_PACKAGES
  "$repo_root/setup.sh" --test-scenario roles >/dev/null
  : > "$log"
  WRAPPER_LOG="$log" PATH="$bin:$PATH" HSS_ROLES_FILE="$HOME/.config/hypr/roles.json" \
    "$HOME/dotfiles/.config/hypr/scripts/notification_control.sh" "$action"
  assert_argv "$provider $action" "$@"
}

# These argv contracts are taken from swaync-client --help and the upstream
# makoctl(1), dunstctl(1), and fnottctl(1) command references.
run_control swaync toggle swaync-client -t -sw
run_control swaync dnd swaync-client -d -sw
run_control mako toggle makoctl dismiss --all
run_control mako dnd makoctl mode -t do-not-disturb
run_control dunst toggle dunstctl history-pop
run_control dunst dnd dunstctl set-paused toggle
run_control fnott toggle fnottctl dismiss all
export ROLE_NOTIFICATIONS=fnott
"$repo_root/setup.sh" --test-scenario roles >/dev/null
printf 'unchanged' > "$log"
WRAPPER_LOG="$log" PATH="$bin:$PATH" HSS_ROLES_FILE="$HOME/.config/hypr/roles.json" \
  "$HOME/dotfiles/.config/hypr/scripts/notification_control.sh" dnd
[[ $(<"$log") == unchanged ]]
printf 'ok - notification provider controls use documented exact argv and fnott DND is a no-op\n'

jq -e '
  .[0].controls == "off"
  and (.[0]["modules-left"] | index("controls") | not)
  and (.[0]["modules-left"] | index("hyprland-workspaces") != null)
' "$repo_root/dotfiles/.config/nwg-panel/bar" >/dev/null
jq -e '
  .[0].controls == "off"
  and (.[0]["modules-center"] | index("hyprland-taskbar") != null)
  and (.[0]["modules-center"] | index("sway-taskbar") | not)
' "$repo_root/dotfiles/.config/nwg-panel/dock" >/dev/null
printf 'ok - nwg-panel profiles disable generic controls and use Hyprland modules\n'
