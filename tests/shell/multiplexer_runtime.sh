#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"

base=$(mktemp -d)
trap 'rm -rf -- "$base"' EXIT
fixture="$base/fixture with spaces"
setup_role_fixture "$fixture"

bin="$fixture/bin"
log="$fixture/terminal-argv.log"
mkdir -p "$bin"
cat > "$bin/kitty" <<'STUB'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$WRAPPER_LOG"
STUB
chmod +x "$bin/kitty"
for executable in alacritty zellij; do
  ln -s "$bin/kitty" "$bin/$executable"
done
export PATH="$bin:$PATH"

# Existing source trees are not replaced with fresh templates during an upgrade.
python - "$HOME/dotfiles/.config/hypr/sources" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
for name, current, previous in (
    ("keybindings.lua", 'bind(control .. " + Y", "Open Preferred Multiplexer", hl.dsp.exec_cmd(apps.multiplex))', 'bind(control .. " + Y", "Open Preferred Terminal", hl.dsp.exec_cmd(apps.hyprscripts .. "/term_exec.sh -- " .. apps.multiplex))'),
    ("keybindings.conf", 'bindd = $mainMod1, Y, Open Preferred Multiplexer, exec, $multiplex', 'bindd = $mainMod1, Y, Open Preferred Terminal, exec, $hyprscripts/term_exec.sh -- $multiplex'),
):
    path = root / name
    text = path.read_text()
    assert current in text
    path.write_text(text.replace(current, previous))
PY

run_shortcut_case() {
  local primary=$1 expected=$2 root app_variables encoded shortcut conf
  set_role_defaults
  export ROLE_MULTIPLEXER=$primary
  export ROLE_MULTIPLEXER_PACKAGES='tmux zellij herdr-bin'
  "$repo_root/setup.sh" --test-scenario roles >/dev/null

  jq -e --arg primary "$primary" '
    .roles.multiplexer.package == $primary
    and ([.selected.multiplexer[].package] == ["tmux", "zellij", "herdr-bin"])
  ' "$HOME/.config/hypr/roles.json" >/dev/null

  for root in sources sources_example; do
    app_variables="$HOME/dotfiles/.config/hypr/$root/app_variables.lua"
    encoded=$(sed -n 's/^[[:space:]]*multiplex = \(.*\),$/\1/p' "$app_variables")
    shortcut=$(jq -er . <<<"$encoded")
    eval "set -- $shortcut"
    [[ $# -eq 3 ]]
    [[ $1 == "$HOME/.config/hypr/scripts/term_exec.sh" ]]
    [[ $2 == -- ]]
    [[ $3 == "$expected" ]]

    conf="$HOME/dotfiles/.config/hypr/$root/app_variables.conf"
    grep -Fqx "\$multiplex = $shortcut" "$conf"
    grep -Fq 'Open Preferred Multiplexer", hl.dsp.exec_cmd(apps.multiplex)' \
      "$HOME/dotfiles/.config/hypr/$root/keybindings.lua"
    grep -Fqx 'bindd = $mainMod1, Y, Open Preferred Multiplexer, exec, $multiplex' \
      "$HOME/dotfiles/.config/hypr/$root/keybindings.conf"
  done

  : > "$log"
  WRAPPER_LOG="$log" HSS_ROLES_FILE="$HOME/.config/hypr/roles.json" "$@"
  mapfile -d '' argv < "$log"
  [[ ${argv[0]} == -e ]]
  [[ ${argv[1]} == "$expected" ]]
  [[ ${#argv[@]} -eq 2 ]]
}

run_shortcut_case tmux tmux
run_shortcut_case zellij zellij
run_shortcut_case herdr-bin herdr
printf 'ok - each primary multiplexer generates one literal selected-terminal shortcut with a spaced home path\n'

set_role_defaults
export ROLE_TERMINAL=alacritty
export ROLE_MULTIPLEXER=tmux
export ROLE_MULTIPLEXER_PACKAGES='tmux zellij'
HSS_RELIABILITY_ACTION=autostart-extras \
  "$repo_root/setup.sh" --test-scenario reliability >/dev/null
for root in sources sources_example; do
  autostart="$HOME/dotfiles/.config/hypr/$root/autostart.lua"
  [[ $(grep -Fxc '    -- hl.exec_cmd("alacritty -e zellij -l ~/.config/zellij/layouts/sysmon.kdl", { workspace = "3 silent" })' "$autostart") -eq 1 ]]
done

export ROLE_MULTIPLEXER=zellij
HSS_RELIABILITY_ACTION=autostart-extras \
  "$repo_root/setup.sh" --test-scenario reliability >/dev/null
for root in sources sources_example; do
  autostart="$HOME/dotfiles/.config/hypr/$root/autostart.lua"
  [[ $(grep -Fxc '    hl.exec_cmd("alacritty -e zellij -l ~/.config/zellij/layouts/sysmon.kdl", { workspace = "3 silent" })' "$autostart") -eq 1 ]]
done

export ROLE_TERMINAL=kitty
HSS_RELIABILITY_ACTION=autostart-extras \
  "$repo_root/setup.sh" --test-scenario reliability >/dev/null
for root in sources sources_example; do
  autostart="$HOME/dotfiles/.config/hypr/$root/autostart.lua"
  [[ $(grep -Fxc '    hl.exec_cmd(apps.hyprscripts .. "/run_once.sh kitty-layout kitty --session ~/.config/kitty/my_layout.conf", { workspace = "3 silent" })' "$autostart") -eq 1 ]]
  [[ $(grep -Fxc '    -- hl.exec_cmd("kitty -e zellij -l ~/.config/zellij/layouts/sysmon.kdl", { workspace = "3 silent" })' "$autostart") -eq 1 ]]
done
printf 'ok - Zellij-specific Alacritty startup follows the primary while Kitty keeps its dashboard\n'
