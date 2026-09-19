#!/usr/bin/env bash
# A closed PATH ensures no host package manager or sudo can be invoked.
set -euo pipefail
TEST_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SCRIPT="$TEST_DIR/../scripts/system_update.sh"
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
bin="$fixture/bin"
home="$fixture/home"
state="$fixture/state"
calls="$fixture/calls"
log="$state/hyprland-simple-setup/system-update.log"

mock() {
    printf '#!/usr/bin/bash\n%s\n' "$2" > "$bin/$1"
    chmod +x "$bin/$1"
}
package_mock() {
    mock "$1" '
name=${0##*/}
printf "%s" "$name" >> "$MOCK_CALLS"
printf " <%s>" "$@" >> "$MOCK_CALLS"
printf "\n" >> "$MOCK_CALLS"
printf "output from %s\n" "$name"
if [[ ${MOCK_READ_INPUT:-0} == 1 ]]; then
    read -r answer
    printf "answer=<%s>\n" "$answer" >> "$MOCK_CALLS"
fi
exit "${MOCK_STATUS:-0}"'
}
reset() {
    rm -rf -- "$bin" "$home" "$state"
    mkdir -p -- "$bin" "$home"
    : > "$calls"
    for tool in mkdir dirname tee; do ln -s "/usr/bin/$tool" "$bin/$tool"; done
    mock id 'printf "%s\n" "${MOCK_UID:-1000}"'
    mock sudo 'printf "sudo" >> "$MOCK_CALLS"; printf " <%s>" "$@" >> "$MOCK_CALLS"; printf "\n" >> "$MOCK_CALLS"; exec "$@"'
    package_mock pacman
    mock_status=0
    mock_uid=1000
    read_input=0
    custom_log=""
}
run() {
    if output=$(PATH="$bin" HOME="$home" XDG_STATE_HOME="$state" \
        WAYBAR_UPDATE_LOG_FILE="$custom_log" MOCK_CALLS="$calls" \
        MOCK_STATUS="$mock_status" MOCK_UID="$mock_uid" MOCK_READ_INPUT="$read_input" \
        /usr/bin/bash "$SCRIPT" "$@" 2>&1); then
        status=0
    else
        status=$?
    fi
}
expect() {
    [[ $status == "$1" ]] || { printf 'Expected %s, got %s: %s\n' "$1" "$status" "$output" >&2; exit 1; }
}

reset
package_mock paru
package_mock yay
run --function update_arch
expect 0
[[ $(<"$calls") == 'paru <-Syu>' ]]
[[ $output == *'confirmations remain enabled'* ]]
grep -Fq 'output from paru' "$log"
grep -Fq '[SESSION_START]' "$log"
grep -Fq '[SESSION_END] status=0' "$log"
printf 'ok - full update prefers paru, preserves prompts and writes the default log\n'

reset
package_mock yay
run --function update_arch
expect 0
[[ $(<"$calls") == 'yay <-Syu>' ]]
printf 'ok - full update uses yay when paru is absent\n'

reset
run --function update_arch
expect 0
[[ $(<"$calls") == $'sudo <pacman> <-Syu>\npacman <-Syu>' ]]
[[ $output == *'AUR updates will be skipped'* ]]
printf 'ok - absent AUR helper uses a full pacman upgrade with an explicit notice\n'

reset
package_mock paru
package_mock yay
run --function update_arch_without_aur
expect 0
[[ $(<"$calls") == $'sudo <pacman> <-Syu>\npacman <-Syu>' ]]
printf 'ok - official-only mode never invokes an AUR helper\n'

reset
package_mock paru
package_mock yay
mock_status=42
run --function update_arch
expect 42
[[ $(<"$calls") == 'paru <-Syu>' ]]
grep -Fq '[SESSION_END] status=42' "$log"
[[ $output == *'No fallback update was attempted'* ]]
printf 'ok - helper failure is logged and propagated without fallback\n'

reset
mock_status=23
run --function update_arch_without_aur
expect 23
printf 'ok - pacman failure propagates\n'

reset
mock_uid=0
run --function update_arch
expect 77
[[ ! -s $calls && ! -e $log ]]
printf 'ok - root invocation is refused before an update\n'

reset
for args in '' '--function wrong' '--function update_arch extra' '--other update_arch'; do
    read -r -a argv <<< "$args"
    run "${argv[@]}"
    expect 2
    [[ ! -s $calls && ! -e $log ]]
done
printf 'ok - invalid interfaces fail before side effects\n'

reset
rm -- "$bin/pacman"
run --function update_arch
expect 127
[[ ! -s $calls ]]
reset
rm -- "$bin/sudo"
run --function update_arch_without_aur
expect 127
[[ ! -s $calls ]]
printf 'ok - missing dependencies cannot fall through to host commands\n'

reset
custom_log="$fixture/log with spaces.txt"
package_mock paru
read_input=1
run --function update_arch <<< 'confirmed input'
expect 0
[[ $(<"$calls") == $'paru <-Syu>\nanswer=<confirmed input>' ]]
grep -Fq '[SESSION_END] status=0' "$custom_log"
printf 'ok - log override preserves spaces and package prompts retain stdin\n'

reset
mkdir -p "$log"
run --function update_arch_without_aur
[[ $status != 0 && ! -s $calls ]]
printf 'ok - inaccessible log prevents starting a transaction\n'

reset
rm -- "$bin/tee"
mock tee 'exit 73'
run --function update_arch_without_aur
expect 73
[[ ! -s $calls ]]
printf 'ok - failed initial log streaming prevents a transaction\n'
