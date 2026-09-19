#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
export HOME="$fixture/home"
export XDG_STATE_HOME="$fixture/state"
export XDG_RUNTIME_DIR="$fixture/runtime"
export HYPRLAND_INSTANCE_SIGNATURE="test-hypr-session"
export HSS_STARTUP_INITIAL_DELAY_SECONDS=0
export HSS_STARTUP_TIMEOUT_SECONDS=0
export HSS_STARTUP_POLL_SECONDS=0.01
export HSS_ROLES_FILE="$HOME/.config/hypr/roles.json"
export HSS_STARTUP_STATE_HELPER="$HOME/.config/hypr/scripts/startup_state.sh"
export HSS_TRIAGE_HELPER="$HOME/.local/scripts/troubleshoot_with_agent.sh"
export TEST_NOTIFY_LOG="$fixture/notify.jsonl"
export TEST_PROCESS_LOG="$fixture/process.log"
bin="$fixture/bin"
mkdir -p "$HOME/.config/hypr/scripts" "$HOME/.config/hypr/sources" "$HOME/.local/scripts" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR" "$bin"
printf '%s\n' '    hl.exec_cmd(apps.hyprscripts .. "/fix-dolphin.sh")' > "$HOME/.config/hypr/sources/autostart.lua"
cp "$repo_root/dotfiles/.config/hypr/scripts/Startup_check.sh" "$HOME/.config/hypr/scripts/"
cp "$repo_root/dotfiles/.config/hypr/scripts/startup_state.sh" "$HOME/.config/hypr/scripts/"
cp "$repo_root/dotfiles/.local/scripts/troubleshoot_with_agent.py" "$HOME/.local/scripts/"
cp "$repo_root/dotfiles/.local/scripts/troubleshoot_with_agent.sh" "$HOME/.local/scripts/"
chmod +x "$HOME/.config/hypr/scripts/"*.sh "$HOME/.local/scripts/"*

cat > "$bin/notify-send" <<'STUB'
#!/usr/bin/env python3
import json, os, sys
with open(os.environ['TEST_NOTIFY_LOG'], 'a') as output:
    output.write(json.dumps(sys.argv[1:]) + '\n')
STUB
cat > "$bin/pgrep" <<'STUB'
#!/usr/bin/env bash
printf '%s\0' "$@" >> "$TEST_PROCESS_LOG"
[[ ${TEST_PROCESSES_MISSING:-0} != 1 ]]
STUB
chmod +x "$bin/notify-send" "$bin/pgrep"
export PATH="$bin:/usr/bin:/bin"

cat > "$HSS_ROLES_FILE" <<'JSON'
{
  "schema_version": 2,
  "roles": {
    "agent": null,
    "terminal": {"package": "kitty", "executable": "kitty", "args": []},
    "notifications": {"package": "swaync", "executable": "swaync"},
    "bar": {"package": "nwg-panel", "executable": "nwg-panel"},
    "dock": {"package": "nwg-panel", "executable": "nwg-panel"},
    "browser": {"package": "zen-browser-bin", "executable": "zen-browser"},
    "gui_editor": {"package": "visual-studio-code-bin", "executable": "code"},
    "launcher": {"package": "wofi", "executable": "wofi"}
  },
  "selected": {"agent": []},
  "agent_executables": {}
}
JSON

for marker in numlock wallpaper dolphin; do
    "$HSS_STARTUP_STATE_HELPER" mark "$marker"
done
: > "$TEST_PROCESS_LOG"
"$HOME/.config/hypr/scripts/Startup_check.sh"
python3 - "$TEST_NOTIFY_LOG" <<'PY'
import json, pathlib, sys
calls = [json.loads(line) for line in pathlib.Path(sys.argv[1]).read_text().splitlines()]
assert len(calls) == 1, calls
assert not any(arg.startswith('--action') for arg in calls[0]), calls
assert calls[0][-1] == 'All expected startup components are ready.', calls
PY
python3 - "$TEST_PROCESS_LOG" <<'PY'
import pathlib, sys
args = pathlib.Path(sys.argv[1]).read_bytes().split(b'\0')
joined = b' '.join(args)
assert joined.count(b'nwg-panel') == 1, joined
for absent in (b'zen-browser', b'code', b'wofi'):
    assert absent not in joined, (absent, joined)
for expected in (b'hyprpaper', b'hypridle', b'wl-clip-persist', b'wl-clipboard-history', b'swaync'):
    assert expected in joined, (expected, joined)
PY
printf 'ok - startup checks only expected long-lived current-user components and deduplicate nwg-panel\n'

rm -rf "$XDG_RUNTIME_DIR/hyprland-simple-setup/startup"
: > "$TEST_NOTIFY_LOG"
: > "$TEST_PROCESS_LOG"
set +e
TEST_PROCESSES_MISSING=1 "$HOME/.config/hypr/scripts/Startup_check.sh"
status=$?
set -e
[[ $status -eq 1 ]]
python3 - "$TEST_NOTIFY_LOG" <<'PY'
import json, pathlib, sys
calls = [json.loads(line) for line in pathlib.Path(sys.argv[1]).read_text().splitlines()]
assert len(calls) >= 2, calls
assert all(not any(arg.startswith('--action') for arg in call) for call in calls), calls
assert any('Dolphin setup did not run' in call[-1] for call in calls), calls
assert any('No automatic recovery was attempted.' in call[-1] for call in calls), calls
PY
[[ ! -d $XDG_STATE_HOME/hyprland-simple-setup/agent-triage ]]
printf 'ok - agent None keeps ordinary failure notifications and performs zero triage dispatches\n'

producer_home="$fixture/producer-home"
mkdir -p "$producer_home/.config/hypr/scripts"
cp "$repo_root/dotfiles/.config/hypr/scripts/startup_state.sh" "$producer_home/.config/hypr/scripts/"
cat > "$bin/kbuildsycoca6" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$bin/kbuildsycoca6"
HOME="$producer_home" HSS_STARTUP_STATE_HELPER="$producer_home/.config/hypr/scripts/startup_state.sh" \
    "$repo_root/dotfiles/.config/hypr/scripts/fix-dolphin.sh"
HOME="$producer_home" HSS_STARTUP_STATE_HELPER="$producer_home/.config/hypr/scripts/startup_state.sh" \
    "$producer_home/.config/hypr/scripts/startup_state.sh" has dolphin
printf 'ok - Dolphin producer publishes readiness only after its command succeeds\n'
