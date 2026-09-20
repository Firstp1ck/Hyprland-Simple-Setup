#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"

fixture=""
cleanup() {
  [[ -z $fixture ]] || rm -rf -- "$fixture"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$*" >&2
  return 1
}

assert_line() {
  local expected=$1 file=$2 description=$3
  grep -Fqx -- "$expected" "$file" || fail "$description: expected line '$expected' in $file"
}

assert_contains() {
  local expected=$1 file=$2 description=$3
  grep -Fq -- "$expected" "$file" || fail "$description: expected '$expected' in $file"
}

assert_argv() {
  local log=$1 description=$2
  shift 2
  local -a actual=()
  mapfile -d '' actual < "$log"
  if ((${#actual[@]} != $#)); then
    fail "$description: expected $# argv fields, got ${#actual[@]}"
    return
  fi
  local index=0 expected
  for expected in "$@"; do
    if [[ ${actual[$index]} != "$expected" ]]; then
      fail "$description: argv[$index] expected '$expected', got '${actual[$index]}'"
      return
    fi
    index=$((index + 1))
  done
}

install_argv_stub() {
  local fixture_root=$1 roles_file=$2 browser terminal launcher dmenu executable
  mkdir -p "$fixture_root/bin"
  cat > "$fixture_root/bin/argv-stub" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
{
  printf '%s\0' "${0##*/}"
  printf '%s\0' "$@"
} > "${WRAPPER_LOG:?WRAPPER_LOG is required}"
if [[ -n ${STUB_EXEC_PID_FILE:-} ]]; then
  printf '%s\n' "$$" > "$STUB_EXEC_PID_FILE"
  sleep 3
fi
STUB
  cat > "$fixture_root/bin/hyprctl" <<'HYPRCTL'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  clients)
    for _ in {1..50}; do
      [[ -s ${STUB_EXEC_PID_FILE:?} ]] && break
      sleep 0.01
    done
    if [[ ${STUB_WINDOW_MISSING:-0} == 1 ]]; then
      printf '[]\n'
    else
      if [[ $(jq -r '.roles.terminal.package' "$HSS_ROLES_FILE") == konsole ]]; then
        printf '[{"class":"org.kde.konsole","title":"hss-clipboard — Konsole","pid":%s,"floating":%s}]\n' \
          "$(<"$STUB_EXEC_PID_FILE")" "${STUB_WINDOW_FLOATING:-false}"
      else
        printf '[{"class":"hss-clipboard","pid":%s,"floating":%s}]\n' \
          "$(<"$STUB_EXEC_PID_FILE")" "${STUB_WINDOW_FLOATING:-false}"
      fi
    fi
    ;;
  *)
    {
      printf 'hyprctl'
      printf ' %q' "$@"
      printf '\n'
    } >> "${STUB_HYPRCTL_LOG:?}"
    ;;
esac
HYPRCTL
  cat > "$fixture_root/bin/sleep" <<'SLEEP'
#!/usr/bin/env bash
if [[ ${STUB_SLEEP_NOOP:-0} == 1 ]]; then
  exit 0
fi
exec /usr/bin/sleep "$@"
SLEEP
  chmod +x "$fixture_root/bin/argv-stub" "$fixture_root/bin/hyprctl" "$fixture_root/bin/sleep"
  browser=$(jq -er '.roles.browser.executable' "$roles_file")
  terminal=$(jq -er '.roles.terminal.executable' "$roles_file")
  launcher=$(jq -er '.roles.launcher.executable' "$roles_file")
  dmenu=$(jq -er '.roles.launcher.dmenu_executable' "$roles_file")
  for executable in "$browser" "$terminal" "$launcher" "$dmenu"; do
    ln -sf "$fixture_root/bin/argv-stub" "$fixture_root/bin/$executable"
  done
}

assert_generated_metadata() {
  local role=$1 package=$2 roles_file=$3 expected
  expected=$(jq -ce --arg role "$role" --arg package "$package" --arg home "$HOME" '
    .roles[$role].options[]
    | select(.package == $package)
    | walk(if type == "string" and startswith("{HOME}/") then $home + ltrimstr("{HOME}") else . end)
  ' "$repo_root/packages.json")
  if ! jq -e --arg role "$role" --argjson expected "$expected" '
    .schema_version == 2
    and .roles[$role] == $expected
    and (.selected[$role] | any(. == $expected))
  ' "$roles_file" >/dev/null; then
    jq --arg role "$role" '{schema_version, primary: .roles[$role], selected: .selected[$role]}' "$roles_file" >&2
    printf 'expected: %s\n' "$expected" >&2
    fail "roles.json metadata mismatch for $role=$package"
  fi
}

assert_wrapper_argv() {
  local fixture_root=$1 roles_file=$2 package=$3
  local wrapper_log="$fixture_root/wrapper.log"
  local terminal terminal_package launcher dmenu
  local -a terminal_args launcher_args dmenu_args expected
  terminal=$(jq -er '.roles.terminal.executable' "$roles_file")
  terminal_package=$(jq -er '.roles.terminal.package' "$roles_file")
  mapfile -t terminal_args < <(jq -r '.roles.terminal.args[]?' "$roles_file")

  WRAPPER_LOG="$wrapper_log" HSS_ROLES_FILE="$roles_file" PATH="$fixture_root/bin:$PATH" \
    "$HOME/dotfiles/.config/hypr/scripts/term_exec.sh" \
    --app-id hss-matrix --title 'Matrix title' -- payload-command 'argument with spaces'
  expected=("$terminal" "${terminal_args[@]}")
  case "$terminal_package" in
    kitty|alacritty) expected+=(--class hss-matrix --title 'Matrix title' -e) ;;
    ghostty) expected+=(--class=hss-matrix --title='Matrix title' -e) ;;
    foot) expected+=(--app-id=hss-matrix --title='Matrix title') ;;
    konsole) expected+=(--separate -p 'tabtitle=hss-matrix' -e) ;;
    *) fail "unexpected terminal package in wrapper test: $terminal_package"; return ;;
  esac
  expected+=(payload-command 'argument with spaces')
  assert_argv "$wrapper_log" "terminal wrapper for $package" "${expected[@]}"

  launcher=$(jq -er '.roles.launcher.executable' "$roles_file")
  mapfile -t launcher_args < <(jq -r '.roles.launcher.args[]?' "$roles_file")
  WRAPPER_LOG="$wrapper_log" HSS_ROLES_FILE="$roles_file" PATH="$fixture_root/bin:$PATH" \
    "$HOME/dotfiles/.config/hypr/scripts/menu_exec.sh" extra-argument
  assert_argv "$wrapper_log" "launcher wrapper for $package" \
    "$launcher" "${launcher_args[@]}" extra-argument

  dmenu=$(jq -er '.roles.launcher.dmenu_executable' "$roles_file")
  mapfile -t dmenu_args < <(jq -r '.roles.launcher.dmenu_args[]?' "$roles_file")
  WRAPPER_LOG="$wrapper_log" HSS_ROLES_FILE="$roles_file" PATH="$fixture_root/bin:$PATH" \
    "$HOME/dotfiles/.config/hypr/scripts/menu_exec.sh" --dmenu prompt-value
  assert_argv "$wrapper_log" "dmenu wrapper for $package" \
    "$dmenu" "${dmenu_args[@]}" prompt-value
}

assert_clipboard_behavior() {
  local fixture_root=$1 roles_file=$2 package=$3 floating=$4
  local wrapper_log="$fixture_root/consumer-wrapper.log"
  local executable terminal_package terminal_pid clipboard_command
  local -a args expected

  executable=$(jq -er '.roles.terminal.executable' "$roles_file")
  terminal_package=$(jq -er '.roles.terminal.package' "$roles_file")
  mapfile -t args < <(jq -r '.roles.terminal.args[]?' "$roles_file")
  clipboard_command='wl-clipboard-history -l 376 | fzf --bind "ctrl-alt-y:execute-silent(echo {} | sed -E \"s/.*,(.*)/\1/\" | wl-copy)+abort"'
  : > "$fixture_root/hyprctl.log"
  rm -f -- "$fixture_root/terminal.pid"
  WRAPPER_LOG="$wrapper_log" \
  STUB_EXEC_PID_FILE="$fixture_root/terminal.pid" \
  STUB_HYPRCTL_LOG="$fixture_root/hyprctl.log" \
  STUB_WINDOW_FLOATING="$floating" \
  HSS_ROLES_FILE="$roles_file" \
  PATH="$fixture_root/bin:$PATH" \
    "$HOME/dotfiles/.config/waybar/scripts/clipboard.sh"
  terminal_pid=$(<"$fixture_root/terminal.pid")
  expected=("$executable" "${args[@]}")
  case "$terminal_package" in
    kitty|alacritty) expected+=(--class hss-clipboard --title Clipboard -e) ;;
    ghostty) expected+=(--class=hss-clipboard --title=Clipboard -e) ;;
    foot) expected+=(--app-id=hss-clipboard --title=Clipboard) ;;
    konsole) expected+=(--separate -p tabtitle=hss-clipboard -e) ;;
    *) fail "unexpected terminal package in clipboard test: $terminal_package"; return ;;
  esac
  expected+=(sh -c "$clipboard_command")
  assert_argv "$wrapper_log" "clipboard terminal argv for $package" "${expected[@]}"
  assert_contains "dispatch focuswindow pid:$terminal_pid" "$fixture_root/hyprctl.log" 'clipboard focuses its stable-class window'
  assert_contains 'resizeactive\ exact\ 50%\ 55%' "$fixture_root/hyprctl.log" 'clipboard window is resized'
  assert_contains 'dispatch\ centerwindow' "$fixture_root/hyprctl.log" 'clipboard window is centered'
  if [[ $floating == true ]]; then
    if grep -Fq 'togglefloating' "$fixture_root/hyprctl.log"; then
      fail "already-floating clipboard was toggled back to tiled for $package"
    fi
  else
    assert_contains 'dispatch\ togglefloating' "$fixture_root/hyprctl.log" 'tiled clipboard is made floating'
  fi
  kill "$terminal_pid" 2>/dev/null || true
  wait "$terminal_pid" 2>/dev/null || true
}

assert_clipboard_timeout() {
  local fixture_root=$1 roles_file=$2 output status terminal_pid
  : > "$fixture_root/hyprctl.log"
  rm -f -- "$fixture_root/terminal.pid"
  set +e
  output=$(WRAPPER_LOG="$fixture_root/consumer-wrapper.log" \
    STUB_EXEC_PID_FILE="$fixture_root/terminal.pid" \
    STUB_HYPRCTL_LOG="$fixture_root/hyprctl.log" \
    STUB_WINDOW_MISSING=1 \
    STUB_SLEEP_NOOP=1 \
    HSS_ROLES_FILE="$roles_file" \
    PATH="$fixture_root/bin:$PATH" \
      "$HOME/dotfiles/.config/waybar/scripts/clipboard.sh" 2>&1)
  status=$?
  set -e
  [[ $status -ne 0 ]] || fail 'clipboard timeout unexpectedly succeeded'
  grep -Fq 'clipboard window not detected within 5 seconds' <<<"$output" || fail 'clipboard timeout error was not reported'
  if grep -Fq 'focuswindow' "$fixture_root/hyprctl.log"; then
    fail 'clipboard timeout attempted to focus a missing window'
  fi
  terminal_pid=$(<"$fixture_root/terminal.pid")
  kill "$terminal_pid" 2>/dev/null || true
  wait "$terminal_pid" 2>/dev/null || true
}

assert_role_consumer_behavior() {
  local role=$1 fixture_root=$2 roles_file=$3 package=$4
  local wrapper_log="$fixture_root/consumer-wrapper.log"
  local executable browser_url
  local -a args

  case "$role" in
    browser)
      executable=$(jq -er '.roles.browser.executable' "$roles_file")
      mapfile -t args < <(jq -r '.roles.browser.args[]?' "$roles_file")
      browser_url='https://www.meteoschweiz.admin.ch/lokalprognose/muri-ag/5630.html#forecast-tab=weekly-overview'
      WRAPPER_LOG="$wrapper_log" HSS_ROLES_FILE="$roles_file" PATH="$fixture_root/bin:$PATH" \
        "$HOME/dotfiles/.config/waybar/scripts/weather.sh"
      assert_argv "$wrapper_log" "weather browser argv for $package" \
        "$executable" "${args[@]}" "$browser_url"
      ;;
    terminal)
      assert_clipboard_behavior "$fixture_root" "$roles_file" "$package" false
      assert_clipboard_behavior "$fixture_root" "$roles_file" "$package" true
      [[ $package != kitty ]] || assert_clipboard_timeout "$fixture_root" "$roles_file"
      ;;
  esac
}

assert_common_consumers() {
  local roles_file=$1
  local hypr_root="$HOME/dotfiles/.config/hypr/sources"
  local waybar="$HOME/dotfiles/.config/waybar/config.jsonc"
  local pypr="$HOME/dotfiles/.config/pypr/config.toml"

  assert_contains 'hl.dsp.exec_cmd(apps.multiplex)' "$hypr_root/keybindings.lua" 'Lua multiplexer keybinding uses generated action'
  assert_contains 'term_exec.sh' "$hypr_root/app_variables.lua" 'Lua multiplexer action uses selected terminal wrapper'
  assert_contains 'hl.exec_cmd(apps.editor, { workspace = "1 silent" }) -- hss-role:gui-editor-autostart' "$hypr_root/autostart.lua" 'Lua autostart uses selected GUI editor'
  assert_contains 'role_exec.sh notifications' "$hypr_root/autostart.lua" 'Lua autostart uses selected notifications'
  assert_contains 'role_exec.sh bar' "$hypr_root/autostart.lua" 'Lua autostart uses selected bar'
  assert_contains 'hl.exec_cmd(apps.browser, { workspace = "2 silent" })' "$hypr_root/autostart.lua" 'Lua autostart uses selected browser'
  for app_id in hss-scratchpad hss-notes hss-clipboard; do
    assert_contains "window_rule(\"$app_id\"" "$hypr_root/windows_and_workspaces.lua" "Lua stable window rule $app_id"
  done

  assert_contains "\"on-click\": \"\$HOME/.config/hypr/scripts/menu_exec.sh --toggle\"" "$waybar" 'Waybar launcher action uses menu wrapper'
  assert_contains "\"drun\": \"\$HOME/.config/hypr/scripts/menu_exec.sh\"" "$waybar" 'Waybar dmenu action uses menu wrapper'
  assert_contains 'term_exec.sh --app-id hss-keybinds' "$waybar" 'Waybar editor action uses terminal wrapper'
  assert_contains '.roles.tui_editor.editor_bin' "$waybar" 'Waybar editor action resolves selected editor'
  assert_contains '"hss-scratchpad"' "$waybar" 'Waybar ignores stable scratchpad app ID'
  assert_contains '"hss-clipboard"' "$waybar" 'Waybar ignores stable clipboard app ID'

  assert_line 'command = "~/.config/hypr/scripts/term_exec.sh --app-id hss-scratchpad --title Scratchpad -- bash"' "$pypr" 'Pyprland uses terminal wrapper'
  assert_line 'command = "~/.config/hypr/scripts/role_exec.sh audio"' "$pypr" 'Pyprland uses selected audio role'
  if [[ $(jq -r '.roles.terminal.package' "$roles_file") == konsole ]]; then
    assert_line 'class = "org.kde.konsole"' "$pypr" 'Pyprland uses native Konsole class'
    assert_line 'match_by = "title"' "$pypr" 'Pyprland uses stable Konsole title'
    assert_line 'title = "re:^hss-scratchpad($| )"' "$pypr" 'Konsole scratchpad title contract'
  else
    assert_line 'class = "hss-scratchpad"' "$pypr" 'Pyprland uses stable scratchpad class'
  fi

  assert_contains 'term_exec.sh' "$HOME/dotfiles/.config/hypr/scripts/notes.sh" 'notes use terminal wrapper'
  assert_contains '.roles.tui_editor.editor_bin' "$HOME/dotfiles/.config/hypr/scripts/notes.sh" 'notes resolve selected editor'
  assert_contains 'menu_exec.sh" --dmenu' "$HOME/dotfiles/.config/hypr/scripts/repos_wofi.sh" 'repository picker uses menu wrapper'
  assert_contains 'term_exec.sh" --app-id hss-repos' "$HOME/dotfiles/.config/hypr/scripts/repos_wofi.sh" 'repository picker uses terminal wrapper'
  assert_contains '.roles.terminal.class' "$HOME/dotfiles/.config/hypr/scripts/toggle_floating.sh" 'floating toggle resolves selected terminal class'

  assert_contains 'term_exec.sh' "$HOME/dotfiles/.config/waybar/scripts/clipboard.sh" 'clipboard uses terminal wrapper'
  assert_contains 'hss-clipboard' "$HOME/dotfiles/.config/waybar/scripts/clipboard.sh" 'clipboard uses stable app ID'
  assert_contains 'roles.json' "$HOME/dotfiles/.config/waybar/scripts/weather.sh" 'weather uses role metadata'
  assert_contains '.roles.browser.executable' "$HOME/dotfiles/.config/waybar/scripts/weather.sh" 'weather resolves selected browser'

  jq -e '.schema_version == 2 and (.roles | length == 15) and (.selected | length == 15)
    and (.agent_executables | type == "object")' "$roles_file" >/dev/null
}

assert_role_consumers() {
  local role=$1 package=$2 roles_file=$3
  local hypr_root="$HOME/dotfiles/.config/hypr/sources"
  local app_variables="$hypr_root/app_variables.lua"
  local fish_env="$HOME/dotfiles/.config/fish/conf.d/01-env.fish"
  local aliases="$HOME/dotfiles/.config/fish/conf.d/02-aliases.fish"
  local command_json executable class shell_path editor dmenu process namespace

  case "$role" in
    browser)
      command_json=$(jq -r '[.roles.browser.executable] + .roles.browser.args | @sh | @json' "$roles_file")
      executable=$(jq -er '.roles.browser.executable' "$roles_file")
      class=$(jq -er '.roles.browser.class' "$roles_file")
      assert_line "    browser = $command_json," "$app_variables" 'Lua browser command'
      assert_line "hl.env(\"BROWSER\", \"$executable\")" "$hypr_root/environment_variables.lua" 'Lua browser environment'
      assert_contains "window_rule(\"$class\", { workspace = \"2 silent\" }) -- hss-role:browser-workspace" "$hypr_root/windows_and_workspaces.lua" 'Lua browser workspace class'
      assert_line "set -gx BROWSER $executable" "$fish_env" 'Fish browser value'
      ;;
    terminal)
      command_json=$(jq -r '[.roles.terminal.executable] + .roles.terminal.args | @sh | @json' "$roles_file")
      executable=$(jq -er '.roles.terminal.executable' "$roles_file")
      assert_line "    terminal = $command_json," "$app_variables" 'Lua terminal command'
      assert_line "set -gx TERMINAL $executable" "$fish_env" 'Fish terminal value'
      ;;
    shell)
      shell_path=$(jq -er '.roles.shell.shell_path' "$roles_file")
      grep -Fq "chsh -s $shell_path -- $(id -un)" "$STUB_LOG" || fail "chsh argv mismatch for $package"
      ;;
    gui_editor)
      assert_contains 'role_exec.sh' "$app_variables" 'Lua GUI editor wrapper executable'
      assert_contains 'gui_editor' "$app_variables" 'Lua GUI editor wrapper role'
      ;;
    tui_editor)
      editor=$(jq -er '.roles.tui_editor.editor_bin' "$roles_file")
      assert_line "set -gx EDITOR $editor" "$fish_env" 'Fish EDITOR value'
      assert_line "set -gx VISUAL $editor" "$fish_env" 'Fish VISUAL value'
      assert_line "set -gx MANPAGER '$editor'" "$fish_env" 'Fish MANPAGER value'
      assert_contains "set -l editor \$EDITOR" "$HOME/dotfiles/.config/fish/functions/vim.fish" 'Fish vim function uses EDITOR'
      if [[ $package == neovim ]]; then
        assert_line "alias vi='nvim'; alias vim='nvim' # hss-role:editor-aliases" "$aliases" 'Neovim aliases'
      elif grep -Fq '# hss-role:editor-aliases' "$aliases"; then
        fail "Neovim-only aliases remain for $package"
      fi
      ;;
    launcher)
      command_json=$(jq -nr --arg executable "$HOME/.config/hypr/scripts/menu_exec.sh" '[$executable] | @sh | @json')
      dmenu=$(jq -r '[.roles.launcher.dmenu_executable] + .roles.launcher.dmenu_args | join(" ")' "$roles_file")
      process=$(jq -er '.roles.launcher.process' "$roles_file")
      namespace=$(jq -er '.roles.launcher.namespace' "$roles_file")
      assert_line "    menu = $command_json," "$app_variables" 'Lua launcher command'
      assert_contains 'menu_exec.sh' "$hypr_root/keybindings.lua" 'Lua launcher toggle wrapper'
      assert_contains '--toggle' "$hypr_root/keybindings.lua" 'Lua launcher toggle mode'
      assert_contains "namespace = \"$namespace\"" "$hypr_root/windows_and_workspaces.lua" 'Lua launcher namespace'
      assert_line "set -gx MENU_DMENU \"$HOME/.config/hypr/scripts/menu_exec.sh --dmenu\"" "$fish_env" 'Fish dmenu wrapper'
      ;;
    agent)
      assert_contains 'hss-role:agent-path' "$hypr_root/environment_variables.lua" 'Hyprland agent PATH'
      assert_contains 'hss-role:agent-path' "$fish_env" 'Fish agent PATH'
      ;;
    multiplexer)
      executable=$(jq -er '.roles.multiplexer.executable' "$roles_file")
      command_json=$(jq -nr --arg helper "$HOME/.config/hypr/scripts/term_exec.sh" --arg executable "$executable" '[$helper, "--", $executable] | @sh | @json')
      assert_line "    multiplex = $command_json," "$app_variables" 'Lua multiplexer shortcut command'
      ;;
    notifications|bar|dock|calendar|bluetooth|network|audio)
      :
      ;;
    *) fail "unknown role in matrix: $role" ;;
  esac
}

count=0
while IFS=$'\t' read -r role package; do
  fixture=$(mktemp -d)
  setup_role_fixture "$fixture"
  set_role_defaults
  set_role_value "$role" "$package"

  if ! output=$("$repo_root/setup.sh" --test-scenario roles 2>&1); then
    printf 'not ok - %s=%s\n%s\n' "$role" "$package" "$output" >&2
    rm -rf "$fixture"
    exit 1
  fi

  roles_file="$HOME/.config/hypr/roles.json"
  assert_generated_metadata "$role" "$package" "$roles_file"
  assert_common_consumers "$roles_file"
  assert_role_consumers "$role" "$package" "$roles_file"
  install_argv_stub "$fixture" "$roles_file"
  assert_wrapper_argv "$fixture" "$roles_file" "$package"
  assert_role_consumer_behavior "$role" "$fixture" "$roles_file" "$package"

  dry_output=$(DRY_RUN=true "$repo_root/setup.sh" --test-scenario roles 2>&1) || {
    printf 'not ok - dry-run %s=%s\n%s\n' "$role" "$package" "$dry_output" >&2
    rm -rf "$fixture"
    exit 1
  }
  grep -Fq "$HOME/dotfiles/.config/hypr/sources/app_variables.lua" <<<"$dry_output"
  grep -Fq "$HOME/.config/hypr/roles.json" <<<"$dry_output"

  count=$((count + 1))
  printf 'ok - %s=%s metadata, consumers, wrappers, and dry-run\n' "$role" "$package"
  rm -rf -- "$fixture"
  fixture=""
done < <(jq -r '.roles | to_entries[] | .key as $role | .value.options[] | [$role, .package] | @tsv' "$repo_root/packages.json")

[[ $count -eq 62 ]] || fail "expected 62 role cases, got $count"
printf 'ok - 62 role options passed metadata and behavioral assertions\n'
