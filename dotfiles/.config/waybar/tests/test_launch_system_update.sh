#!/usr/bin/env bash
# Test service/terminal dispatch without invoking a service manager or package manager.
set -euo pipefail
TEST_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SCRIPT="$TEST_DIR/../scripts/launch_system_update.sh"
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
bin="$fixture/bin"
home="$fixture/home with spaces"
state="$fixture/state with spaces"
run_log="$fixture/run.argv"
mkdir -p "$bin" "$home/.config/hypr/scripts" "$home/.config/waybar/scripts"
for tool in awk jq; do ln -s "/usr/bin/$tool" "$bin/$tool"; done
mock() {
    printf '#!/usr/bin/bash\n%s\n' "$2" > "$1"
    chmod +x "$1"
}
mock "$bin/systemd-run" 'printf "%s\0" "$@" > "$MOCK_RUN_LOG"'
mock "$bin/systemctl" 'if [[ $* == *show-environment* ]]; then printf "HYPRLAND_INSTANCE_SIGNATURE=test-session\n"; else printf "%s\n" "${MOCK_ACTIVE:-inactive}"; fi'
mock "$bin/hyprctl" '
if [[ ${1:-} == clients ]]; then
    if [[ ${MOCK_KONSOLE:-0} == 1 ]]; then
        printf "[{\"class\":\"org.kde.konsole\",\"title\":\"waybar-system-update - Konsole\",\"address\":\"0x123\"}]\n"
    else
        printf "[{\"class\":\"waybar-system-update\",\"address\":\"0x123\"}]\n"
    fi
fi'
mock "$bin/notify-send" 'exit 0'
mock "$home/.config/hypr/scripts/term_exec.sh" 'exit 0'
mock "$home/.config/waybar/scripts/system_update.sh" 'exit 0'
mock "$home/.config/waybar/scripts/update_maintenance_action.sh" 'exit 0'
override=""
active=inactive
konsole=0
run() {
    : > "$run_log"
    if output=$(PATH="$bin" HOME="$home" XDG_STATE_HOME="$state" \
        WAYBAR_UPDATE_SCRIPT="$override" WAYBAR_UPDATE_LOG_FILE="" \
        WAYBAR_UPDATE_UNIT=waybar-system-update \
        WAYBAR_UPDATE_TERMINAL_LAUNCHER="$home/.config/hypr/scripts/term_exec.sh" \
        WAYBAR_UPDATE_MAINTENANCE_SCRIPT="$home/.config/waybar/scripts/update_maintenance_action.sh" \
        WAYBAR_UPDATE_CLASS=waybar-system-update WAYBAR_UPDATE_TITLE='System Update' \
        MOCK_RUN_LOG="$run_log" MOCK_ACTIVE="$active" MOCK_KONSOLE="$konsole" \
        /usr/bin/bash "$SCRIPT" "$@" 2>&1); then status=0; else status=$?; fi
}
assert_dispatch() {
    local expected_script=$1 expected_function=$2
    [[ $status == 0 ]] || { printf '%s\n' "$output" >&2; exit 1; }
    mapfile -d '' args < "$run_log"
    [[ ${args[-3]} == "$expected_script" && ${args[-2]} == --function && ${args[-1]} == "$expected_function" ]]
    [[ ${args[6]} == "--setenv=WAYBAR_UPDATE_LOG_FILE=$state/hyprland-simple-setup/system-update.log" ]]
    [[ ${args[7]} == "$home/.config/hypr/scripts/term_exec.sh" ]]
    [[ ${args[8]} == --app-id && ${args[9]} == waybar-system-update ]]
    [[ ${args[10]} == --title && ${args[11]} == 'System Update' && ${args[12]} == -- ]]
}
run
assert_dispatch "$home/.config/waybar/scripts/system_update.sh" update_arch
[[ $output != *'Set WAYBAR_UPDATE_SCRIPT'* ]]
printf 'ok - update launcher uses the bundled updater and forwards its log path by default\n'
run --without-aur
assert_dispatch "$home/.config/waybar/scripts/system_update.sh" update_arch_without_aur
printf 'ok - official-only action dispatches the bundled no-AUR function\n'

override="$fixture/custom updater"
mock "$override" 'exit 0'
run
assert_dispatch "$override" update_arch
printf 'ok - custom executable override remains optional and argv-safe\n'

override=""
konsole=1
run
assert_dispatch "$home/.config/waybar/scripts/system_update.sh" update_arch
printf 'ok - update window detection accepts the Konsole title identity\n'

active=active
run
[[ $status == 0 && ! -s $run_log && $output == *'already running'* ]]
printf 'ok - active update service is not started twice\n'
active=inactive
run --unknown
[[ $status == 2 && ! -s $run_log ]]
run --without-aur extra
[[ $status == 2 && ! -s $run_log ]]
printf 'ok - invalid modes fail before service launch\n'

override="$fixture/missing updater"
run
[[ $status == 126 && ! -s $run_log && $output == *'missing or not executable'* ]]
printf 'ok - invalid override reports a missing executable rather than running another command\n'
