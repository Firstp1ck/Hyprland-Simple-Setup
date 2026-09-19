#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"

fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults
export SELECTED_PACMAN_PACKAGES='dolphin alacritty vivaldi-ffmpeg-codecs brave-bin'
export SELECTED_AUR_PACKAGES='github-desktop-bin firefox cursor-bin'
export USER_ADDED_PACMAN_PACKAGES='ghostty git zen-browser-bin'
export USER_ADDED_AUR_PACKAGES='vivaldi visual-studio-code-bin'
export DRY_RUN=false

# setup.sh is source-safe; this test calls only role selection functions in the disposable fixture.
# shellcheck source=setup.sh
source "$repo_root/setup.sh"
resolve_package_registry
load_role_selections
prepare_package_selections

contains() {
  local needle=$1
  shift
  local value
  for value in "$@"; do
    [[ $value != "$needle" ]] || return 0
  done
  return 1
}

for package in dolphin git kitty fish neovim wofi; do
  contains "$package" "${SELECTED_PACMAN_LIST[@]}"
done
for package in github-desktop-bin zen-browser-bin visual-studio-code-bin; do
  contains "$package" "${SELECTED_AUR_LIST[@]}"
done

role_managed_inputs=(alacritty ghostty firefox vivaldi vivaldi-ffmpeg-codecs brave-bin cursor-bin)
for package in "${role_managed_inputs[@]}"; do
  if contains "$package" "${SELECTED_PACMAN_LIST[@]}" || contains "$package" "${SELECTED_AUR_LIST[@]}"; then
    printf 'not ok - unselected role-managed package survived normalization: %s\n' "$package" >&2
    exit 1
  fi
done
if contains zen-browser-bin "${SELECTED_PACMAN_LIST[@]}" \
  || contains visual-studio-code-bin "${SELECTED_PACMAN_LIST[@]}" \
  || contains kitty "${SELECTED_AUR_LIST[@]}"; then
  printf 'not ok - selected role package was retained under the wrong source\n' >&2
  exit 1
fi
printf 'ok - explicit and user-added lists retain unrelated packages and re-add only selected roles by source\n'
