#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults

PYTHONDONTWRITEBYTECODE=1 python - "$repo_root" <<'PY'
import importlib.util
import json
import sys
spec = importlib.util.spec_from_file_location('waybar_roles', sys.argv[1] + '/scripts/lib/update-waybar-roles.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
source = '''{
// keep this comment and URL
"unrelated": "https://example.org/a/*literal*/", /* keep block */
"clock": {"format": "{:%H:%M}", /* local note */ "on-click": "old",},
"custom/notification": {"interval": 1, "exec-if": "old"},
}'''
for text in (source, '[' + source + ', ' + source + ',]'):
    result = module.update_document(text)
    assert '/* local note */' in result and '// keep this comment' in result
    assert '/* keep block */' in result
    parsed = json.loads(module.json_text(result))
    for bar in parsed if isinstance(parsed, list) else [parsed]:
        assert bar['unrelated'] == 'https://example.org/a/*literal*/'
        assert bar['clock']['format'] == '{:%H:%M}'
        assert bar['clock']['on-click'].endswith('/float_calendar.sh')
        assert 'interval' not in bar['custom/notification']
        assert 'exec-if' not in bar['custom/notification']
    assert module.update_document(result) == result
for obj in ('{"exec-if":"x","interval":1}', '{"interval":1,}',
            '{"interval":1,"exec-if":"x",}', '{/* nothing */}'):
    result = module.update_object(obj, {'exec': 'new'}, ('interval', 'exec-if'))
    assert json.loads(module.json_text(result)) == {'exec': 'new'}
try:
    module.update_document('{"clock": invalid}')
except ValueError:
    pass
else:
    raise AssertionError('invalid input accepted')
PY
printf 'ok - JSONC actions preserve comments, strings, unrelated values, arrays, trailing commas and idempotence\n'

waybar="$HOME/dotfiles/.config/waybar/config.jsonc"
printf '{ // custom JSONC\n "clock": { "format": "keep", },\n}\n' > "$waybar"
before=$(sha256sum "$waybar")
ROLE_BAR=ironbar "$repo_root/setup.sh" --test-scenario roles >/dev/null
[[ $(sha256sum "$waybar") == "$before" ]]
"$repo_root/setup.sh" --test-scenario roles >/dev/null
grep -Fq '// custom JSONC' "$waybar"
grep -Fq '"format": "keep"' "$waybar"
grep -Fq '/float_calendar.sh' "$waybar"
printf 'ok - commented Waybar upgrade works; alternate bar leaves it unchanged\n'

export ROLE_TERMINAL=konsole ROLE_AUDIO=alsa-utils
"$repo_root/setup.sh" --test-scenario roles >/dev/null
python - "$HOME/dotfiles/.config/pypr/config.toml" <<'PY'
import sys, tomllib
from pathlib import Path
pads = tomllib.loads(Path(sys.argv[1]).read_text())['scratchpads']
for role, title in [('term', 'hss-scratchpad'), ('volume', 'hss-audio')]:
    assert pads[role]['match_by'] == 'title'
    assert pads[role]['class'] == 'org.kde.konsole'
    assert pads[role]['title'] == 're:^' + title + '($| )'
PY
export ROLE_TERMINAL=foot
"$repo_root/setup.sh" --test-scenario roles >/dev/null
python - "$HOME/dotfiles/.config/pypr/config.toml" <<'PY'
import sys, tomllib
from pathlib import Path
pads = tomllib.loads(Path(sys.argv[1]).read_text())['scratchpads']
assert pads['term']['match_by'] == pads['volume']['match_by'] == 'class'
assert pads['term']['class'] == 'hss-scratchpad'
assert pads['volume']['class'] == 'hss-audio'
PY
printf 'ok - Konsole uses title matchers and switching terminal restores class matchers\n'

cat > "$HOME/.config/waybar/scripts/launch_qt_gui.sh" <<'STUB'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$GUI_LOG"
STUB
chmod +x "$HOME/.config/waybar/scripts/launch_qt_gui.sh"
for entry in calendar:merkuro calendar:gnome-calendar audio:pavucontrol-qt audio:qastools; do
  role=${entry%%:*}
  package=${entry#*:}
  set_role_value "$role" "$package"
  "$repo_root/setup.sh" --test-scenario roles >/dev/null
  GUI_LOG="$fixture/gui" "$HOME/.config/hypr/scripts/role_window.sh" "$role" 'argument with spaces'
  mapfile -d '' argv < "$fixture/gui"
  [[ ${argv[0]} != *hss-* && ${argv[4]} == -- && ${argv[-1]} == 'argument with spaces' ]]
  case "$package" in
    merkuro) [[ ${argv[0]} == '^org\.kde\.merkuro\.calendar$' && ${argv[5]} == merkuro-calendar ]] ;;
    gnome-calendar) [[ ${argv[0]} == '^org\.gnome\.Calendar$' && ${argv[5]} == gnome-calendar ]] ;;
    pavucontrol-qt) [[ ${argv[0]} == '^pavucontrol-qt$' && ${argv[5]} == pavucontrol-qt ]] ;;
    qastools) [[ ${argv[0]} == '^qasmixer$' && ${argv[5]} == qasmixer ]] ;;
  esac
done
grep -Fq 'org.kde.merkuro.calendar|org.gnome.Calendar' "$HOME/.config/hypr/sources/windows_and_workspaces.lua"
grep -Fq 'pavucontrol-qt|qasmixer' "$HOME/.config/hypr/sources/windows_and_workspaces.lua"
printf 'ok - native GUI calendar and audio classes reach the existing focus/float helper\n'

# Model process identities without ever querying/killing a host desktop process.
bin="$fixture/bin"
mkdir -p "$bin"
cat > "$bin/pgrep" <<'STUB'
#!/usr/bin/env bash
[[ $3 == -f ]]
printf '%s\n' '/usr/bin/python /usr/bin/nwg-panel -c hss-panels' | grep -Eq -- "$4"
STUB
cat > "$bin/pkill" <<'STUB'
#!/usr/bin/env bash
[[ $3 == --signal && $4 == RTMIN && $5 == -f ]]
printf '%s\n' '/usr/bin/python /usr/bin/nwg-panel -c hss-panels' | grep -Eq -- "$6"
printf 'bar-only\n' > "$KILL_LOG"
STUB
chmod +x "$bin/pgrep" "$bin/pkill"
ROLE_BAR=nwg-panel ROLE_DOCK=nwg-panel "$repo_root/setup.sh" --test-scenario roles >/dev/null
PATH="$bin:$PATH" KILL_LOG="$fixture/kill" "$HOME/.config/hypr/scripts/toggle_waybar.sh"
[[ $(<"$fixture/kill") == bar-only ]]
printf 'ok - nwg-panel bar toggle signals the shared process instead of terminating the dock\n'
