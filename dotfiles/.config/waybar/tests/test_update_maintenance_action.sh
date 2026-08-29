#!/usr/bin/env bash
# Deterministic tests for update_maintenance_action.sh using PATH-injected mocks.

set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
readonly ACTION_SCRIPT="${TEST_DIR}/../scripts/update_maintenance_action.sh"
TMP_DIR="$(mktemp -d)"
readonly TMP_DIR
readonly MOCK_BIN="${TMP_DIR}/bin"
readonly TEST_HOME="${TMP_DIR}/home"
readonly TEST_LOG="${TMP_DIR}/Linux Setup detailed.log"
readonly COMMAND_LOG="${TMP_DIR}/commands.log"

LAST_OUTPUT=""
LAST_STATUS=0
TESTS_RUN=0

cleanup() {
    rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

pass() {
    ((TESTS_RUN += 1))
    printf 'ok %d - %s\n' "$TESTS_RUN" "$1"
}

reset_sandbox() {
    rm -rf -- "$MOCK_BIN" "$TEST_HOME"
    mkdir -p -- "$MOCK_BIN" "$TEST_HOME"
    : > "$COMMAND_LOG"
    : > "$TEST_LOG"
    unset MOCK_CHECKUPDATES_OUTPUT MOCK_CHECKUPDATES_STATUS MOCK_YAY_OUTPUT MOCK_YAY_STATUS
    unset MOCK_FWUPD_REFRESH_STATUS MOCK_FWUPD_GET_OUTPUT MOCK_FWUPD_GET_STATUS MOCK_FWUPD_UPDATE_STATUS
}

write_mock() {
    local name=$1
    local body=$2

    printf '#!/usr/bin/bash\n%s\n' "$body" > "${MOCK_BIN}/${name}"
    chmod +x "${MOCK_BIN}/${name}"
}

mock_checkupdates() {
    # The mock expands these variables only when the generated script runs.
    # shellcheck disable=SC2016
    write_mock checkupdates 'printf "%s" "${MOCK_CHECKUPDATES_OUTPUT:-}"; exit "${MOCK_CHECKUPDATES_STATUS:-0}"'
}

mock_yay() {
    # shellcheck disable=SC2016
    write_mock yay 'printf "yay" > "$MOCK_COMMAND_LOG"; for arg in "$@"; do printf " <%s>" "$arg" >> "$MOCK_COMMAND_LOG"; done; printf "\n" >> "$MOCK_COMMAND_LOG"; printf "%s" "${MOCK_YAY_OUTPUT:-}"; exit "${MOCK_YAY_STATUS:-0}"'
}

mock_sudo() {
    # shellcheck disable=SC2016
    write_mock sudo 'printf "argc=%s\n" "$#" > "$MOCK_COMMAND_LOG"; for arg in "$@"; do printf "arg=%s\n" "$arg" >> "$MOCK_COMMAND_LOG"; done'
}

mock_sudo_passthrough() {
    # shellcheck disable=SC2016
    write_mock sudo 'printf "sudo" >> "$MOCK_COMMAND_LOG"; for arg in "$@"; do printf " <%s>" "$arg" >> "$MOCK_COMMAND_LOG"; done; printf "\n" >> "$MOCK_COMMAND_LOG"; "$@"'
}

mock_fwupdmgr() {
    # shellcheck disable=SC2016
    write_mock fwupdmgr '
        printf "fwupdmgr" >> "$MOCK_COMMAND_LOG"
        for arg in "$@"; do printf " <%s>" "$arg" >> "$MOCK_COMMAND_LOG"; done
        printf "\n" >> "$MOCK_COMMAND_LOG"
        case "${1:-}" in
            refresh) exit "${MOCK_FWUPD_REFRESH_STATUS:-0}" ;;
            get-updates)
                printf "%s" "${MOCK_FWUPD_GET_OUTPUT:-}"
                exit "${MOCK_FWUPD_GET_STATUS:-0}"
                ;;
            update) exit "${MOCK_FWUPD_UPDATE_STATUS:-0}" ;;
            *) exit 64 ;;
        esac
    '
}

mock_dependency() {
    write_mock "$1" 'exit 97'
}

mock_less() {
    # shellcheck disable=SC2016
    write_mock less 'printf "LESSSECURE=%s\n" "${LESSSECURE:-}" > "$MOCK_COMMAND_LOG"; printf "argc=%s\n" "$#" >> "$MOCK_COMMAND_LOG"; for arg in "$@"; do printf "arg=%s\n" "$arg" >> "$MOCK_COMMAND_LOG"; done'
}

run_action() {
    if LAST_OUTPUT=$(PATH="$MOCK_BIN" \
        HOME="$TEST_HOME" \
        WAYBAR_UPDATE_LOG_FILE="$TEST_LOG" \
        MOCK_COMMAND_LOG="$COMMAND_LOG" \
        MOCK_CHECKUPDATES_OUTPUT="${MOCK_CHECKUPDATES_OUTPUT:-}" \
        MOCK_CHECKUPDATES_STATUS="${MOCK_CHECKUPDATES_STATUS:-0}" \
        MOCK_YAY_OUTPUT="${MOCK_YAY_OUTPUT:-}" \
        MOCK_YAY_STATUS="${MOCK_YAY_STATUS:-0}" \
        MOCK_FWUPD_REFRESH_STATUS="${MOCK_FWUPD_REFRESH_STATUS:-0}" \
        MOCK_FWUPD_GET_OUTPUT="${MOCK_FWUPD_GET_OUTPUT:-}" \
        MOCK_FWUPD_GET_STATUS="${MOCK_FWUPD_GET_STATUS:-0}" \
        MOCK_FWUPD_UPDATE_STATUS="${MOCK_FWUPD_UPDATE_STATUS:-0}" \
        /usr/bin/bash "$ACTION_SCRIPT" "$@" 2>&1); then
        LAST_STATUS=0
    else
        LAST_STATUS=$?
    fi
}

assert_status() {
    local expected=$1

    [[ "$LAST_STATUS" == "$expected" ]] \
        || fail "expected status ${expected}, got ${LAST_STATUS}; output: ${LAST_OUTPUT}"
}

assert_contains() {
    local needle=$1

    [[ "$LAST_OUTPUT" == *"$needle"* ]] \
        || fail "output did not contain '${needle}': ${LAST_OUTPUT}"
}

assert_command_log() {
    local expected=$1
    local actual=""

    actual=$(<"$COMMAND_LOG")
    [[ "$actual" == "$expected" ]] \
        || fail "unexpected command log; expected '${expected}', got '${actual}'"
}

reset_sandbox
mock_checkupdates
MOCK_CHECKUPDATES_OUTPUT=$'linux 6.12.1-1 -> 6.12.2-1\n'
run_action check
assert_status 0
assert_contains 'linux 6.12.1-1 -> 6.12.2-1'
assert_contains "The optional AUR helper 'yay' is not installed"
pass 'check reports official updates and handles absent yay'

reset_sandbox
mock_checkupdates
MOCK_CHECKUPDATES_STATUS=2
run_action check
assert_status 0
assert_contains 'No official repository updates are available.'
pass 'check treats checkupdates status 2 as no updates'

reset_sandbox
mock_checkupdates
MOCK_CHECKUPDATES_STATUS=1
MOCK_CHECKUPDATES_OUTPUT='temporary database failure'
run_action check
assert_status 1
assert_contains 'checkupdates failed with exit status 1.'
assert_contains 'temporary database failure'
pass 'check distinguishes a hard checkupdates failure'

reset_sandbox
run_action check
assert_status 127
assert_contains "Required command 'checkupdates' was not found."
pass 'check reports a missing required dependency'

reset_sandbox
mock_checkupdates
mock_yay
MOCK_CHECKUPDATES_STATUS=2
MOCK_YAY_OUTPUT=$'aur-package 1.0-1 -> 1.1-1\n'
run_action check
assert_status 0
assert_contains 'aur-package 1.0-1 -> 1.1-1'
assert_command_log 'yay <-Qua>'
pass 'check routes AUR queries through yay -Qua when yay exists'

reset_sandbox
run_action firmware
assert_status 127
assert_contains "Required command 'fwupdmgr' was not found."
[[ ! -s "$COMMAND_LOG" ]] || fail 'missing fwupdmgr unexpectedly invoked a command'
pass 'firmware fails clearly instead of installing a missing dependency'

reset_sandbox
mock_fwupdmgr
mock_sudo_passthrough
MOCK_FWUPD_GET_OUTPUT='No upgradable devices'
run_action firmware
assert_status 0
assert_contains 'No firmware updates are available.'
assert_command_log $'sudo <fwupdmgr> <refresh> <--force>\nfwupdmgr <refresh> <--force>\nfwupdmgr <get-updates>'
pass 'firmware reports no updates after a successful refresh and check'

reset_sandbox
mock_fwupdmgr
mock_sudo_passthrough
MOCK_FWUPD_REFRESH_STATUS=4
run_action firmware
assert_status 4
assert_contains 'fwupdmgr refresh failed with exit status 4.'
assert_command_log $'sudo <fwupdmgr> <refresh> <--force>\nfwupdmgr <refresh> <--force>'
pass 'firmware propagates metadata refresh failures'

reset_sandbox
mock_fwupdmgr
mock_sudo_passthrough
MOCK_FWUPD_GET_STATUS=5
MOCK_FWUPD_GET_OUTPUT='device query failed'
run_action firmware
assert_status 5
assert_contains 'fwupdmgr get-updates failed with exit status 5.'
assert_contains 'device query failed'
assert_command_log $'sudo <fwupdmgr> <refresh> <--force>\nfwupdmgr <refresh> <--force>\nfwupdmgr <get-updates>'
pass 'firmware distinguishes and propagates get-updates failures'

reset_sandbox
mock_fwupdmgr
mock_sudo_passthrough
MOCK_FWUPD_GET_OUTPUT='Updates available'
MOCK_FWUPD_UPDATE_STATUS=6
run_action firmware
assert_status 6
assert_contains 'fwupdmgr update failed with exit status 6.'
assert_command_log $'sudo <fwupdmgr> <refresh> <--force>\nfwupdmgr <refresh> <--force>\nfwupdmgr <get-updates>\nsudo <fwupdmgr> <update> <-y>\nfwupdmgr <update> <-y>'
pass 'firmware invokes update only when available and propagates install failures'

reset_sandbox
mock_dependency pacdiff
mock_sudo
run_action review-pacnew
assert_status 0
assert_command_log $'argc=1\narg=pacdiff'
pass 'review-pacnew invokes sudo pacdiff interactively'

reset_sandbox
mock_dependency paccache
mock_sudo
run_action clean-cache
assert_status 0
assert_command_log $'argc=2\narg=paccache\narg=-r'
pass 'clean-cache invokes exactly sudo paccache -r'

reset_sandbox
mock_less
printf '%s\n' \
    'preamble' \
    '[2026-01-01] [SESSION_START] id=first' \
    'first command' \
    'separator' \
    '[2026-01-02] [SESSION_START] id=latest' \
    'latest command' > "$TEST_LOG"
run_action show-log
assert_status 0
assert_command_log $'LESSSECURE=1\nargc=3\narg=+5g\narg=--\narg='"$TEST_LOG"
pass 'show-log opens the configured log at the latest session in secure less'

reset_sandbox
run_action not-an-action
assert_status 2
assert_contains 'Unknown maintenance action: not-an-action'
[[ ! -s "$COMMAND_LOG" ]] || fail 'invalid action unexpectedly invoked a command'
pass 'invalid actions fail without invoking maintenance commands'

for forbidden in 'pacman -Sc' 'pacman -Scc' 'yay -Sc' 'rm -rf'; do
    if grep -Fq -- "$forbidden" "$ACTION_SCRIPT"; then
        fail "dispatcher contains forbidden command text: ${forbidden}"
    fi
done
pass 'dispatcher contains none of the forbidden cleanup commands'

printf '1..%d\n' "$TESTS_RUN"
