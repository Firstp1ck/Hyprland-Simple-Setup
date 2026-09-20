#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"

fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
setup_role_fixture "$fixture"

input=$'1 2\n2\n\n4 5\n1\n\n2\n\n0\n3\n2\n4\n3\n\n5\n3\n0\n'
output=$(printf '%s' "$input" | NON_INTERACTIVE=false "$repo_root/setup.sh" --test-scenario roles)
grep -Fq 'Select Browser:' <<<"$output"
grep -Fq 'Choose the primary Browser:' <<<"$output"
grep -Fq '0) None' <<<"$output"

roles_file="$HOME/.config/hypr/roles.json"
jq -e '
  .roles.browser.package == "chromium"
  and ([.selected.browser[].package] == ["firefox", "chromium"])
  and .roles.terminal.package == "konsole"
  and ([.selected.terminal[].package] == ["konsole", "foot"])
  and .roles.multiplexer.package == "herdr-bin"
  and ([.selected.multiplexer[].package] == ["herdr-bin"])
  and .roles.notifications.package == "mako"
  and .roles.gui_editor == null and .selected.gui_editor == []
  and .roles.bar.package == "nwg-panel"
  and .roles.dock.package == "nwg-panel"
  and .roles.calendar.package == "calcurse"
  and .roles.bluetooth.package == "bluetui"
  and ([.selected.bluetooth[].package] == ["bluetui"])
  and .roles.network.package == "plasma-nm"
  and .roles.audio.package == "ncpamixer"
  and .roles.launcher.package == "fuzzel"
  and .roles.agent == null and .selected.agent == []
  and .agent_executables == {}
' "$roles_file" >/dev/null
printf 'ok - interactive setup supports single, multiple, optional None, and primary choices\n'

set_role_defaults
export ROLE_BROWSER=chromium
export ROLE_BROWSER_PACKAGES='firefox chromium'
output=$(NON_INTERACTIVE=false "$repo_root/setup.sh" --test-scenario roles)
if grep -Fq 'Select Browser:' <<<"$output"; then
  printf 'not ok - interactive setup prompted despite explicit role environment overrides\n' >&2
  exit 1
fi
jq -e '.roles.browser.package == "chromium" and ([.selected.browser[].package] == ["firefox", "chromium"])' "$roles_file" >/dev/null
printf 'ok - explicit scalar/list environment overrides suppress interactive prompts\n'
