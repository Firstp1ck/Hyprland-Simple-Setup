#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults

managers=(yazi ranger lf nnn mc vifm)
# Generic package lists must not bypass the optional role selection.
export SELECTED_PACMAN_PACKAGES="${managers[*]}"
selected_packages() {
  bash -c '
    set -e
    source "$1/setup.sh"
    resolve_package_registry
    load_role_selections >/dev/null
    prepare_package_selections >/dev/null
    printf "%s\n" "${SELECTED_PACMAN_LIST[@]}"
  ' bash "$repo_root"
}
assert_no_tui_packages() {
  local selected package
  selected=$(selected_packages)
  for package in "${managers[@]}"; do
    if grep -Fxq "$package" <<<"$selected"; then
      printf 'not ok - unselected TUI file manager retained: %s\n' "$package" >&2
      exit 1
    fi
  done
}

unset ROLE_TUI_FILE_MANAGER
"$repo_root/setup.sh" --test-scenario roles >"$fixture/default.log" 2>&1
roles_file="$HOME/.config/hypr/roles.json"
jq -e '.roles.tui_file_manager == null and .selected.tui_file_manager == []
  and .roles.file_manager.package == "dolphin"' "$roles_file" >/dev/null
assert_no_tui_packages

mkdir -p "$fixture/bin"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\0" "$@" > "$TUI_MANAGER_TERMINAL_LOG"' > "$fixture/bin/kitty"
chmod +x "$fixture/bin/kitty"
export TUI_MANAGER_TERMINAL_LOG="$fixture/argv.log"
export ROLE_TUI_FILE_MANAGER_PACKAGES="${managers[*]}"
for package in "${managers[@]}"; do
  export ROLE_TUI_FILE_MANAGER=$package
  "$repo_root/setup.sh" --test-scenario roles >"$fixture/$package.log" 2>&1
  jq -e --arg package "$package" '
    .roles.tui_file_manager.package == $package
    and .roles.tui_file_manager.terminal == true
    and ([.selected.tui_file_manager[].package] == ["yazi", "ranger", "lf", "nnn", "mc", "vifm"])
    and .roles.file_manager.package == "dolphin"' "$roles_file" >/dev/null
  selected=$(selected_packages)
  for member in "${managers[@]}" dolphin; do
    grep -Fxq "$member" <<<"$selected"
  done

  PATH="$fixture/bin:$PATH" "$HOME/.config/hypr/scripts/role_exec.sh" tui_file_manager -- '/tmp/folder with spaces'
  mapfile -d '' argv < "$TUI_MANAGER_TERMINAL_LOG"
  expected=(--class hss-tui_file_manager --title 'tui file manager' -e "$package" '/tmp/folder with spaces')
  [[ ${#argv[@]} == ${#expected[@]} ]]
  for index in "${!expected[@]}"; do
    [[ ${argv[$index]} == "${expected[$index]}" ]]
  done
done

if output=$(ROLE_FILE_MANAGER= "$repo_root/setup.sh" --test-scenario roles 2>&1); then
  printf 'not ok - TUI choices replaced the required graphical file manager\n' >&2
  exit 1
fi
grep -Fq 'ROLE_FILE_MANAGER is required and cannot be empty' <<<"$output"

export ROLE_TUI_FILE_MANAGER=mc
export ROLE_TUI_FILE_MANAGER_PACKAGES='yazi mc'
"$repo_root/setup.sh" --test-scenario roles >"$fixture/subset.log" 2>&1
jq -e '.roles.tui_file_manager.package == "mc"
  and ([.selected.tui_file_manager[].package] == ["yazi", "mc"])' "$roles_file" >/dev/null
selected=$(selected_packages)
for package in yazi mc dolphin; do
  grep -Fxq "$package" <<<"$selected"
done
for package in ranger lf nnn vifm; do
  if grep -Fxq "$package" <<<"$selected"; then
    printf 'not ok - deselected TUI file manager retained: %s\n' "$package" >&2
    exit 1
  fi
done
if output=$(ROLE_TUI_FILE_MANAGER=ranger "$repo_root/setup.sh" --test-scenario roles 2>&1); then
  printf 'not ok - unselected primary was accepted\n' >&2
  exit 1
fi
grep -Fq "primary 'ranger' is not in ROLE_TUI_FILE_MANAGER_PACKAGES" <<<"$output"

export ROLE_TUI_FILE_MANAGER=
export ROLE_TUI_FILE_MANAGER_PACKAGES=
"$repo_root/setup.sh" --test-scenario roles >"$fixture/disabled.log" 2>&1
jq -e '.roles.tui_file_manager == null and .selected.tui_file_manager == []
  and .roles.file_manager.package == "dolphin"' "$roles_file" >/dev/null
assert_no_tui_packages
printf 'ok - all six optional TUI file managers install together and each primary launches in the selected terminal\n'
printf 'ok - subsets, primary validation and None preserve the required graphical file manager\n'
