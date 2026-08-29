#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
readonly SCRIPT="${TEST_DIR}/../scripts/confirm_system_update.sh"
TMP_DIR="$(mktemp -d)"
readonly TMP_DIR
readonly MOCK_BIN="${TMP_DIR}/bin"
readonly CALL_LOG="${TMP_DIR}/calls.log"

cleanup() {
    rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT
mkdir -p -- "$MOCK_BIN"

write_dialog() {
    cat > "${MOCK_BIN}/zenity" <<'EOF'
#!/usr/bin/bash
printf 'dialog' >> "$MOCK_CALL_LOG"
printf ' <%s>' "$@" >> "$MOCK_CALL_LOG"
printf '\n' >> "$MOCK_CALL_LOG"
exit "${MOCK_DIALOG_STATUS:-0}"
EOF
    chmod +x "${MOCK_BIN}/zenity"
}

cat > "${MOCK_BIN}/launcher" <<'EOF'
#!/usr/bin/bash
printf 'launcher\n' >> "$MOCK_CALL_LOG"
EOF
chmod +x "${MOCK_BIN}/launcher"

run_wrapper() {
    local dialog_status=$1

    : > "$CALL_LOG"
    if LAST_OUTPUT=$(PATH="$MOCK_BIN" \
        WAYBAR_UPDATE_DIALOG=zenity \
        WAYBAR_UPDATE_LAUNCHER="${MOCK_BIN}/launcher" \
        MOCK_CALL_LOG="$CALL_LOG" \
        MOCK_DIALOG_STATUS="$dialog_status" \
        /usr/bin/bash "$SCRIPT" 2>&1); then
        LAST_STATUS=0
    else
        LAST_STATUS=$?
    fi
}

assert_not_launched() {
    if grep -Fq 'launcher' "$CALL_LOG"; then
        printf 'Launcher was called unexpectedly.\n' >&2
        exit 1
    fi
}

write_dialog
run_wrapper 0
[[ "$LAST_STATUS" == 0 ]]
grep -Fq 'dialog <--question> <--title=System Update> <--text=Start the system update now?> <--ok-label=Start update> <--cancel-label=Cancel>' "$CALL_LOG"
grep -Fxq 'launcher' "$CALL_LOG"

run_wrapper 1
[[ "$LAST_STATUS" == 0 ]]
assert_not_launched

run_wrapper 5
[[ "$LAST_STATUS" == 5 ]]
[[ "$LAST_OUTPUT" == *'The confirmation dialog failed with exit status 5.'* ]]
assert_not_launched

rm -- "${MOCK_BIN}/zenity"
run_wrapper 0
[[ "$LAST_STATUS" == 127 ]]
[[ "$LAST_OUTPUT" == *"The 'zenity' confirmation dialog is unavailable."* ]]
assert_not_launched

printf 'Waybar update confirmation tests: OK\n'
