#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults

for invalid in '' 'dolphin thunar' unknown-manager; do
  if output=$(ROLE_FILE_MANAGER=dolphin ROLE_FILE_MANAGER_PACKAGES="$invalid" \
      "$repo_root/setup.sh" --test-scenario roles 2>&1); then
    printf 'not ok - invalid file manager membership accepted: %s\n' "$invalid" >&2
    exit 1
  fi
  grep -Eq 'required and cannot be empty|accepts at most one package|unknown package value' <<<"$output"
done
printf 'ok - file manager rejects empty, multiple and unknown choices\n'

mkdir -p "$fixture/bin"
cat > "$fixture/bin/argv-stub" <<'STUB'
#!/usr/bin/env bash
printf '%s\0' "${0##*/}" "$@" > "$FILE_MANAGER_LOG"
STUB
chmod +x "$fixture/bin/argv-stub"
export FILE_MANAGER_LOG="$fixture/argv.log"

for package in dolphin thunar nautilus nemo pcmanfm-qt; do
  export ROLE_FILE_MANAGER=$package
  # Stale generic selections must not install the other file managers.
  export SELECTED_PACMAN_PACKAGES='dolphin thunar nautilus nemo pcmanfm-qt'
  "$repo_root/setup.sh" --test-scenario roles >"$fixture/setup.log" 2>&1
  roles_file="$HOME/.config/hypr/roles.json"
  jq -e --arg package "$package" '
    .roles.file_manager.package == $package
    and ([.selected.file_manager[].package] == [$package])
  ' "$roles_file" >/dev/null
  for root in sources sources_example; do
    lua="$HOME/dotfiles/.config/hypr/$root/app_variables.lua"
    conf="$HOME/dotfiles/.config/hypr/$root/app_variables.conf"
    [[ $(grep -Ec '^[[:space:]]*file_manager[[:space:]]*=' "$lua") == 1 ]]
    grep -Eq 'file_manager = .*role_exec[.]sh.*file_manager' "$lua"
    [[ $(grep -Ec '^[$]fileManager[[:space:]]*=' "$conf") == 1 ]]
    grep -Eq '^[$]fileManager = .*role_exec[.]sh.*file_manager' "$conf"
  done

  selected=$(bash -c '
    set -e
    source "$1/setup.sh"
    resolve_package_registry
    load_role_selections >/dev/null
    prepare_package_selections >/dev/null
    printf "%s\n" "${SELECTED_PACMAN_LIST[@]}"
  ' bash "$repo_root")
  for candidate in dolphin thunar nautilus nemo pcmanfm-qt; do
    if [[ $candidate == "$package" ]]; then
      grep -Fxq "$candidate" <<<"$selected"
    elif grep -Fxq "$candidate" <<<"$selected"; then
      printf 'not ok - unselected file manager survived normalization: %s\n' "$candidate" >&2
      exit 1
    fi
  done

  ln -s "$fixture/bin/argv-stub" "$fixture/bin/$package"
  PATH="$fixture/bin:$PATH" "$HOME/.config/hypr/scripts/role_exec.sh" file_manager -- '/tmp/folder with spaces'
  mapfile -d '' argv < "$FILE_MANAGER_LOG"
  [[ ${#argv[@]} == 2 && ${argv[0]} == "$package" && ${argv[1]} == '/tmp/folder with spaces' ]]
done
printf 'ok - all file managers generate metadata, update shortcuts and launch with literal arguments\n'
printf 'ok - reruns keep one assignment and install only the selected file manager\n'
