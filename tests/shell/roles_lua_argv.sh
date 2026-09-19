#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"

base=$(mktemp -d)
trap 'rm -rf -- "$base"' EXIT
fixture="$base/fixture with spaces"
setup_role_fixture "$fixture"
set_role_defaults

registry_root="$base/registry"
marker="$base/metacharacter-was-executed"
mkdir -p "$registry_root"
jq --arg marker "$marker" '
  [
    "argument with spaces",
    "single quote: '\''",
    "double quote: \"",
    "backslash: \\",
    ("; touch " + $marker + "; #"),
    "{HOME}/path with spaces/back\\slash \"quoted\".css"
  ] as $adversarial_args
  | (.roles.browser.options[] | select(.package == "zen-browser-bin").args) = $adversarial_args
  | (.roles.terminal.options[] | select(.package == "kitty").args) = $adversarial_args
  | (.roles.gui_editor.options[] | select(.package == "visual-studio-code-bin").args) = $adversarial_args
  | (.roles.launcher.options[] | select(.package == "wofi").args) = $adversarial_args
' "$repo_root/packages.json" > "$registry_root/packages.json"
export HYPRLAND_SETUP_DIR="$registry_root"

"$repo_root/setup.sh" --test-scenario roles >/dev/null
roles_file="$HOME/.config/hypr/roles.json"
app_variables="$HOME/dotfiles/.config/hypr/sources/app_variables.lua"
argv_bin="$base/argv-bin"
lua_bin=$(command -v lua || command -v lua5.4) || {
  printf 'not ok - Lua interpreter is required for generated command validation\n' >&2
  exit 1
}
mkdir -p "$argv_bin"
cat > "$argv_bin/argv-stub" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
{
  printf '%s\0' "${0##*/}"
  printf '%s\0' "$@"
} > "${WRAPPER_LOG:?WRAPPER_LOG is required}"
STUB
chmod +x "$argv_bin/argv-stub"

assert_argv() {
  local log=$1 description=$2
  shift 2
  local -a actual=()
  mapfile -d '' actual < "$log"
  [[ ${#actual[@]} -eq $# ]] || {
    printf 'not ok - %s: expected %d argv fields, got %d\n' "$description" "$#" "${#actual[@]}" >&2
    return 1
  }
  local index=0 expected
  for expected in "$@"; do
    [[ ${actual[$index]} == "$expected" ]] || {
      printf "not ok - %s: argv[%d] expected '%s', got '%s'\n" \
        "$description" "$index" "$expected" "${actual[$index]}" >&2
      return 1
    }
    index=$((index + 1))
  done
}

execute_generated_command() {
  local field=$1 role=$2 command executable log
  local -a expected_args
  command=$("$lua_bin" - "$app_variables" "$field" <<'LUA'
local chunk, load_error = loadfile(arg[1])
assert(chunk, load_error)
local variables = chunk()
local command = variables[arg[2]]
assert(type(command) == "string", "missing generated Lua field " .. arg[2])
io.write(command)
LUA
  )
  executable=$(jq -er --arg role "$role" '.roles[$role].executable' "$roles_file")
  mapfile -t expected_args < <(jq -r --arg role "$role" '.roles[$role].args[]' "$roles_file")
  ln -sf "$argv_bin/argv-stub" "$argv_bin/$executable"
  log="$base/$role.argv"
  WRAPPER_LOG="$log" PATH="$argv_bin:$PATH" sh -c "$command"
  assert_argv "$log" "generated Lua $role command" "$executable" "${expected_args[@]}"
}

execute_generated_command browser browser
execute_generated_command terminal terminal
execute_generated_command editor gui_editor
execute_generated_command menu launcher
[[ ! -e $marker ]]
printf 'ok - Lua-loaded generated commands preserve spaces, quotes, backslashes, paths, and literal shell metacharacters\n'
