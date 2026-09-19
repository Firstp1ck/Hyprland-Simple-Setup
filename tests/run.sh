#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runner_tmp=$(mktemp -d)
trap 'rm -rf -- "$runner_tmp"' EXIT

if (($# > 0)); then
  test_files=("$@")
else
  mapfile -d '' test_files < <(
    find "$repo_root/tests/shell" -maxdepth 1 -type f -name '*.sh' \
      ! -name '*_testlib.sh' -print0 | LC_ALL=C sort -z
  )
fi

if ((${#test_files[@]} == 0)); then
  printf 'not ok - no shell tests found\n' >&2
  exit 1
fi

passed=0
failed=0
for index in "${!test_files[@]}"; do
  test_file=${test_files[$index]}
  test_name=${test_file#"$repo_root/"}
  if [[ $(basename -- "$test_file") == *_testlib.sh ]]; then
    printf 'not ok - source-only helper is not a test program: %s\n' "$test_name" >&2
    failed=$((failed + 1))
    continue
  fi
  if [[ ! -f $test_file || $test_file != *.sh ]]; then
    printf 'not ok - invalid test program: %s\n' "$test_name" >&2
    failed=$((failed + 1))
    continue
  fi

  case_root="$runner_tmp/case-$index"
  case_home="$case_root/home"
  case_config="$case_home/.config"
  case_state="$case_root/state"
  case_runtime="$case_root/runtime"
  output="$case_root/output"
  mkdir -p -- "$case_config" "$case_state" "$case_runtime"
  chmod 700 "$case_runtime"

  if env \
    -u ROLE_BROWSER -u ROLE_BROWSER_PACKAGES -u ROLE_SHELL -u ROLE_SHELL_PACKAGES \
    -u ROLE_TERMINAL -u ROLE_TERMINAL_PACKAGES -u ROLE_NOTIFICATIONS -u ROLE_NOTIFICATIONS_PACKAGES \
    -u ROLE_TUI_EDITOR -u ROLE_TUI_EDITOR_PACKAGES -u ROLE_GUI_EDITOR -u ROLE_GUI_EDITOR_PACKAGES \
    -u ROLE_BAR -u ROLE_BAR_PACKAGES -u ROLE_DOCK -u ROLE_DOCK_PACKAGES \
    -u ROLE_CALENDAR -u ROLE_CALENDAR_PACKAGES -u ROLE_BLUETOOTH -u ROLE_BLUETOOTH_PACKAGES \
    -u ROLE_NETWORK -u ROLE_NETWORK_PACKAGES -u ROLE_AUDIO -u ROLE_AUDIO_PACKAGES \
    -u ROLE_LAUNCHER -u ROLE_LAUNCHER_PACKAGES -u ROLE_AGENT -u ROLE_AGENT_PACKAGES \
    -u SELECTED_PACMAN_PACKAGES -u SELECTED_AUR_PACKAGES \
    -u STUB_INSTALLED -u STUB_LOG -u HSS_TEST_MODE \
    HOME="$case_home" \
    XDG_CONFIG_HOME="$case_config" \
    XDG_STATE_HOME="$case_state" \
    XDG_RUNTIME_DIR="$case_runtime" \
    HYPRLAND_SETUP_DIR="$repo_root" \
    PATH="$repo_root/tests/stubs:$PATH" \
    bash "$test_file" >"$output" 2>&1; then
    cat -- "$output"
    printf 'ok - %s\n' "$test_name"
    passed=$((passed + 1))
  else
    status=$?
    cat -- "$output"
    printf 'not ok - %s (exit %d)\n' "$test_name" "$status" >&2
    failed=$((failed + 1))
  fi
done

printf '%d test programs passed, %d failed\n' "$passed" "$failed"
((failed == 0))
