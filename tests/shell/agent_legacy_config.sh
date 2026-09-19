#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults
export ROLE_AGENT=pi ROLE_SHELL=bash

for root in sources sources_example; do
    directory="$HOME/dotfiles/.config/hypr/$root"
    printf '%s\n' \
      '# retain this existing config' \
      '  exec-once = hyprctl keyword input:kb_numlock true && date "+%Y-%m-%d %H:%M:%S" > /tmp/numlock-set  ' \
      'exec-once = hyprctl keyword input:kb_numlock true && audit-helper /tmp/numlock-set' \
      'exec-once = hyprctl keyword input:kb_numlock true && date "+%Y-%m-%d %H:%M:%S" > /tmp/numlock-set && audit-helper' \
      'exec-once = custom-user-command' > "$directory/autostart.conf"
    printf '%s\n' '# preserve custom environment' 'env = USER_SETTING,keep-me' > "$directory/environment_variables.conf"
    python3 - "$directory/autostart.lua" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
current = '    hl.exec_cmd("hyprctl keyword input:kb_numlock true && " .. apps.hyprscripts .. "/startup_state.sh mark numlock")'
legacy = 'hl.exec_cmd([[hyprctl keyword input:kb_numlock true && date "+%Y-%m-%d %H:%M:%S" > /tmp/numlock-set]])'
assert current in text
path.write_text(text.replace(current, '  ' + legacy + '  \n    ' + legacy + '; hl.exec_cmd("keep-custom")'))
PY
done

before=$(sha256sum "$HOME/.config/hypr/sources/"{autostart,environment_variables}.conf)
DRY_RUN=true "$repo_root/setup.sh" --test-scenario roles > "$fixture/dry-run.log"
DRY_RUN=true HSS_RELIABILITY_ACTION=autostart-extras "$repo_root/setup.sh" --test-scenario reliability >> "$fixture/dry-run.log"
[[ $(sha256sum "$HOME/.config/hypr/sources/"{autostart,environment_variables}.conf) == "$before" ]]
for _ in 1 2; do
    "$repo_root/setup.sh" --test-scenario roles > "$fixture/configure.log"
    HSS_RELIABILITY_ACTION=autostart-extras "$repo_root/setup.sh" --test-scenario reliability >> "$fixture/configure.log"
done
for root in sources sources_example; do
    directory="$HOME/.config/hypr/$root"
    [[ $(grep -Fc 'startup_state.sh mark numlock' "$directory/autostart.conf") -eq 1 ]]
    ! grep -Fqx 'exec-once = hyprctl keyword input:kb_numlock true && date "+%Y-%m-%d %H:%M:%S" > /tmp/numlock-set' "$directory/autostart.conf"
    grep -Fqx 'exec-once = hyprctl keyword input:kb_numlock true && audit-helper /tmp/numlock-set' "$directory/autostart.conf"
    grep -Fqx 'exec-once = hyprctl keyword input:kb_numlock true && date "+%Y-%m-%d %H:%M:%S" > /tmp/numlock-set && audit-helper' "$directory/autostart.conf"
    grep -Fqx 'exec-once = custom-user-command' "$directory/autostart.conf"
    [[ $(grep -Fc 'startup_state.sh mark numlock' "$directory/autostart.lua") -eq 1 ]]
    grep -Fq '; hl.exec_cmd("keep-custom")' "$directory/autostart.lua"
    [[ $(grep -Fc '/tmp/numlock-set' "$directory/autostart.lua") -eq 1 ]]
    [[ $(grep -Fc 'hss-role:agent-path' "$directory/environment_variables.conf") -eq 1 ]]
    grep -Fqx 'env = PATH,$HOME/.local/bin:$HOME/.opencode/bin:$PATH # hss-role:agent-path' "$directory/environment_variables.conf"
    grep -Fqx 'env = USER_SETTING,keep-me' "$directory/environment_variables.conf"
done
printf 'ok - exact legacy numlock commands migrate while custom near-matches and PATH settings are preserved\n'

custom="$HOME/.config/hypr/sources/autostart.conf"
printf '%s' 'exec-once = hyprctl keyword input:kb_numlock true && audit-helper /tmp/numlock-set' > "$custom"
custom_before=$(sha256sum "$custom")
HSS_RELIABILITY_ACTION=autostart-extras "$repo_root/setup.sh" --test-scenario reliability > "$fixture/custom.log"
[[ $(sha256sum "$custom") == "$custom_before" ]]
printf 'ok - no-match custom config without a final newline stays byte-identical\n'

ROLE_AGENT= ROLE_AGENT_PACKAGES= "$repo_root/setup.sh" --test-scenario roles > "$fixture/none.log"
for root in sources sources_example; do
    directory="$HOME/.config/hypr/$root"
    ! grep -Fq 'hss-role:agent-path' "$directory/environment_variables.conf"
    ! grep -Fq 'hss-role:agent-path' "$directory/environment_variables.lua"
    grep -Fqx 'env = USER_SETTING,keep-me' "$directory/environment_variables.conf"
done
printf 'ok - agent None removes managed PATH lines from both config variants\n'
