#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults
bin="$fixture/bin"
mkdir -p "$bin"

for script in app_log.sh nwg_panel.sh menu_exec.sh startup_state.sh; do
    rm -- "$HOME/dotfiles/.config/hypr/scripts/$script"
done
rm -- "$HOME/dotfiles/.local/scripts/troubleshoot_with_agent.py" "$HOME/dotfiles/.local/scripts/troubleshoot_with_agent.sh"
HSS_RELIABILITY_ACTION=sync-managed "$repo_root/setup.sh" --test-scenario reliability > "$fixture/sync.log"
for script in app_log.sh nwg_panel.sh menu_exec.sh startup_state.sh; do
    cmp "$repo_root/dotfiles/.config/hypr/scripts/$script" "$HOME/.config/hypr/scripts/$script"
done
for script in troubleshoot_with_agent.py troubleshoot_with_agent.sh; do
    cmp "$repo_root/dotfiles/.local/scripts/$script" "$HOME/dotfiles/.local/scripts/$script"
done
[[ -x $HOME/.config/hypr/scripts/nwg_panel.sh ]]
printf 'ok - existing dotfiles receive panel, menu, startup-state and triage helpers\n'

# nwg-panel v0.10.15 reads controls-settings before defaults and requires settings
# objects to instantiate Hyprland modules: upstream main.py lines 335-380, 762.
python - "$repo_root" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1]) / 'dotfiles/.config/nwg-panel'
for profile in ('bar', 'dock'):
    panels = json.loads((root / profile).read_text())
    assert len(panels) == 1
    panel = panels[0]
    assert isinstance(panel['controls-settings'], dict)
    panel['controls-settings'].setdefault('window-width', 0)
    for group in ('modules-left', 'modules-center', 'modules-right'):
        for name in panel[group]:
            assert isinstance(panel[name], dict), (profile, name)
PY
printf 'ok - nwg-panel profiles satisfy upstream mandatory-settings/module contracts\n'

cat > "$bin/nwg-panel" <<'STUB'
#!/usr/bin/env bash
printf 'start\n' >> "$PANEL_STARTS"
printf '%s\0' "$@" > "$PANEL_ARGV"
printf 'panel diagnostic\n' >&2
STUB
chmod +x "$bin/nwg-panel"
export ROLE_BAR=nwg-panel ROLE_DOCK=nwg-panel
"$repo_root/setup.sh" --test-scenario roles >/dev/null
export PANEL_STARTS="$fixture/panel-starts" PANEL_ARGV="$fixture/panel-argv"
: > "$PANEL_STARTS"
PATH="$bin:$PATH" "$HOME/.config/hypr/scripts/role_exec.sh" bar
PATH="$bin:$PATH" "$HOME/.config/hypr/scripts/role_exec.sh" dock
[[ $(wc -l < "$PANEL_STARTS") -eq 1 ]]
mapfile -d '' args < "$PANEL_ARGV"
[[ ${args[*]} == '-c hss-panels' ]]
config="$HOME/.config/nwg-panel/hss-panels"
signal=$(kill -l RTMIN)
jq -e --argjson signal "$signal" '
    map(.name) == ["bar", "dock"]
    and .[0]["use-sigrt"] == true and .[0].sigrt == $signal
    and .[1]["use-sigrt"] == false
' "$config" >/dev/null
grep -Fq 'panel diagnostic' "$XDG_STATE_HOME/hyprland-simple-setup/apps/bar.log"
printf 'ok - bar and dock share one nwg-panel process and only the bar responds to its toggle signal\n'

export ROLE_BAR=waybar
"$repo_root/setup.sh" --test-scenario roles >/dev/null
: > "$PANEL_STARTS"
PATH="$bin:$PATH" "$HOME/.config/hypr/scripts/role_exec.sh" dock
[[ $(wc -l < "$PANEL_STARTS") -eq 1 ]]
jq -e 'map(.name) == ["dock"] and .[0]["use-sigrt"] == false' "$config" >/dev/null
printf 'ok - nwg-panel dock also starts independently with a different bar\n'

export ROLE_BAR=nwg-panel ROLE_DOCK='' ROLE_DOCK_PACKAGES=''
"$repo_root/setup.sh" --test-scenario roles >/dev/null
PATH="$bin:$PATH" "$HOME/.config/hypr/scripts/role_exec.sh" bar
jq -e 'map(.name) == ["bar"]' "$config" >/dev/null
cp "$config" "$fixture/good-panel"
printf 'invalid JSON\n' > "$HOME/.config/nwg-panel/bar"
: > "$PANEL_STARTS"
if PATH="$bin:$PATH" "$HOME/.config/hypr/scripts/role_exec.sh" bar; then
    printf 'not ok - malformed panel profile accepted\n' >&2; exit 1
fi
cmp "$config" "$fixture/good-panel"
[[ ! -s $PANEL_STARTS ]]
cp "$repo_root/dotfiles/.config/nwg-panel/bar" "$HOME/.config/nwg-panel/bar"
printf 'ok - malformed panel configuration does not overwrite the last generated config or launch\n'

cat > "$bin/launcher-stub" <<'STUB'
#!/usr/bin/env bash
{ printf '%s\0' "${0##*/}"; for arg in "$@"; do printf '%s\0' "$arg"; done; } > "$LAUNCHER_ARGV"
printf '%s' "${BEMENU_BACKEND:-unset}" > "$BACKEND_LOG"
printf '%s\n' "${LAUNCHER_DIAGNOSTIC:-launcher diagnostic}" >&2
if [[ ${DMENU_INPUT:-0} == 1 ]]; then
    IFS= read -r choice
    printf '%s\n' "$choice"
fi
exit "${LAUNCHER_STATUS:-0}"
STUB
chmod +x "$bin/launcher-stub"
for executable in wofi rofi fuzzel bemenu-run bemenu tofi-drun tofi; do
    ln -s "$bin/launcher-stub" "$bin/$executable"
done
export LAUNCHER_ARGV="$fixture/launcher-argv" BACKEND_LOG="$fixture/backend"
for package in wofi rofi fuzzel bemenu tofi; do
    set_role_defaults
    export ROLE_LAUNCHER=$package
    "$repo_root/setup.sh" --test-scenario roles >/dev/null
    PATH="$bin:$PATH" BEMENU_BACKEND=ncurses "$HOME/.config/hypr/scripts/menu_exec.sh"
    mapfile -d '' args < "$LAUNCHER_ARGV"
    case "$package" in
        wofi) [[ ${args[*]} == "wofi --show drun --style $HOME/.config/wofi/menu.css" ]] ;;
        rofi) [[ ${args[*]} == 'rofi -show drun' ]] ;;
        fuzzel) [[ ${#args[@]} -eq 1 && ${args[0]} == fuzzel ]] ;;
        bemenu) [[ ${#args[@]} -eq 1 && ${args[0]} == bemenu-run && $(<"$BACKEND_LOG") == wayland ]] ;;
        tofi) [[ ${args[*]} == 'tofi-drun --drun-launch=true' ]] ;;
    esac
    grep -Fq menu_exec.sh "$HOME/.config/hypr/sources/app_variables.lua"
    if grep -q 'pkill ' "$HOME/.config/hypr/sources/keybindings.lua"; then
        printf 'not ok - keybindings bypass the launcher toggle wrapper\n' >&2
        exit 1
    fi
done
printf 'ok - all five launchers keep their documented argv; bemenu always selects the Wayland renderer\n'

export ROLE_LAUNCHER=bemenu
"$repo_root/setup.sh" --test-scenario roles >/dev/null
selection=$(bash -c '
  set -e
  source "$1/setup.sh"
  resolve_package_registry
  prepare_package_selections
  printf "%s\n" "${SELECTED_PACMAN_LIST[@]}"
' bash "$repo_root")
grep -Fxq bemenu-wayland <<< "$selection"
[[ $(jq -r '.roles.launcher.process' "$HOME/.config/hypr/roles.json") == bemenu-run ]]
# Keep shell syntax literal to test argument handling and log privacy.
# shellcheck disable=SC2016
choice='private choice ; $(touch should-not-exist)'
result=$(printf '%s\n' "$choice" | PATH="$bin:$PATH" DMENU_INPUT=1 \
    "$HOME/.config/hypr/scripts/menu_exec.sh" --dmenu)
[[ $result == "$choice" ]]
if grep -Fq "$choice" "$XDG_STATE_HOME/hyprland-simple-setup/apps/launcher.log"; then
    printf 'not ok - private dmenu choice leaked into the launcher log\n' >&2
    exit 1
fi
printf 'ok - bemenu Wayland dependency is selected and dmenu input/output stays literal and out of logs\n'

export ROLE_LAUNCHER=fuzzel
"$repo_root/setup.sh" --test-scenario roles >/dev/null
set +e
PATH="$bin:$PATH" LAUNCHER_STATUS=42 LAUNCHER_DIAGNOSTIC='simulated renderer failure' \
    "$HOME/.config/hypr/scripts/menu_exec.sh"
status=$?
set -e
[[ $status == 42 ]]
grep -Fq 'simulated renderer failure' "$XDG_STATE_HOME/hyprland-simple-setup/apps/launcher.log"
printf 'ok - launcher errors retain their exit status and stderr for diagnosis\n'

cat > "$bin/pgrep" <<'STUB'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$PROCESS_LOG"
exit 0
STUB
cat > "$bin/pkill" <<'STUB'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$PROCESS_LOG"
exit "${PKILL_STATUS:-0}"
STUB
chmod +x "$bin/pgrep" "$bin/pkill"
: > "$LAUNCHER_ARGV"
PATH="$bin:$PATH" PROCESS_LOG="$fixture/process" "$HOME/.config/hypr/scripts/menu_exec.sh" --toggle
mapfile -d '' args < "$fixture/process"
[[ ${args[*]} == "-u $UID -x -- fuzzel" && ! -s $LAUNCHER_ARGV ]]
printf 'ok - menu toggle targets the current user and exact launcher process\n'

PATH="$bin:$PATH" PROCESS_LOG="$fixture/process" PKILL_STATUS=1 "$HOME/.config/hypr/scripts/menu_exec.sh" --toggle
mapfile -d '' args < "$LAUNCHER_ARGV"
[[ ${#args[@]} -eq 1 && ${args[0]} == fuzzel ]]
: > "$LAUNCHER_ARGV"
set +e
PATH="$bin:$PATH" PROCESS_LOG="$fixture/process" PKILL_STATUS=2 "$HOME/.config/hypr/scripts/menu_exec.sh" --toggle
status=$?
set -e
[[ $status == 2 && ! -s $LAUNCHER_ARGV ]]
printf 'ok - menu opens when no previous process exists but preserves toggle errors\n'
