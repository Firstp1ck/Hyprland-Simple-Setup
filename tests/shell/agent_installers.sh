#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"

fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults

bin="$fixture/agent-bin"
mkdir -p "$bin" "$fixture/run-tmp"
for command in env readlink tail tar gzip; do
  ln -s "$(command -v "$command")" "$bin/$command"
done
ln -s /bin/bash "$bin/bash"
ln -s "${HSS_TEST_INSTALLER_SH:-/bin/sh}" "$bin/sh"

cat > "$bin/id" <<'STUB'
#!/bin/bash
if [[ -f $HOME/root-mode ]]; then
  [[ ${1:-} == -u ]] && printf '0\n' || printf 'root\n'
elif [[ ${1:-} == -u ]]; then
  printf '1000\n'
else
  printf 'fixture-user\n'
fi
STUB
cat > "$bin/node" <<'STUB'
#!/bin/bash
[[ ! -f $HOME/old-node ]]
STUB
cat > "$bin/npm" <<'STUB'
#!/bin/bash
exit 0
STUB
cat > "$bin/setsid" <<'STUB'
#!/bin/bash
printf 'setsid' >> "$HOME/runner.log"
printf ' <%s>' "$@" >> "$HOME/runner.log"
printf '\n' >> "$HOME/runner.log"
[[ ${1:-} != --wait ]] || shift
exec "$@"
STUB
cat > "$bin/timeout" <<'STUB'
#!/bin/bash
printf 'timeout' >> "$HOME/runner.log"
printf ' <%s>' "$@" >> "$HOME/runner.log"
printf '\n' >> "$HOME/runner.log"
if [[ -f $HOME/timeout-mode ]]; then
  exit 124
fi
[[ ${1:-} != --kill-after=10s ]] || shift
[[ ${1:-} != 600s ]] || shift
exec "$@"
STUB
cat > "$bin/curl" <<'STUB'
#!/bin/bash
set -euo pipefail
original=("$@")
if [[ -f $HOME/.curlrc && ${1:-} != --disable ]]; then
  printf 'mock curl loaded ambient configuration\n' >&2
  exit 93
fi
output=
url=
while (($#)); do
  case $1 in
    --output) output=$2; shift 2 ;;
    https://*) url=$1; shift ;;
    *) shift ;;
  esac
done
[[ -n $output && -n $url ]]
printf '%s\n' "$url" >> "$HOME/curl.log"
{
  printf 'curl'
  printf ' <%s>' "${original[@]}"
  printf ' <url=%s>\n' "$url"
} >> "$HOME/curl-argv.log"
case $url in
  https://pi.dev/install.sh) id=pi; executable=pi; destination="$HOME/.local/bin/pi" ;;
  https://opencode.ai/install) id=opencode; executable=opencode; destination="$HOME/.opencode/bin/opencode" ;;
  https://claude.ai/install.sh) id=claude-code; executable=claude; destination="$HOME/.local/bin/claude" ;;
  https://chatgpt.com/codex/install.sh) id=codex-cli; executable=codex; destination="$HOME/.local/bin/codex" ;;
  https://cursor.com/install) id=cursor-cli; executable=cursor-agent; destination="$HOME/.local/bin/cursor-agent" ;;
  *) exit 90 ;;
esac
# The runner invokes this fixture with either sh or bash, regardless of shebang.
/bin/cat > "$output" <<INSTALLER
#!/bin/sh
set -eu
{
  printf 'id=%s\\n' '$id'
  printf 'argv='
  printf '<%s>' "\$@"
  printf '\\nPATH=%s\\n' "\$PATH"
  printf 'NPM_CONFIG_PREFIX=%s\\n' "\${NPM_CONFIG_PREFIX-}"
  printf 'CODEX_NON_INTERACTIVE=%s\\n' "\${CODEX_NON_INTERACTIVE-}"
  printf 'SUDO_PASSWORD=%s\\n' "\${SUDO_PASSWORD-unset}"
  printf 'OPENAI_API_KEY=%s\\n' "\${OPENAI_API_KEY-unset}"
  printf 'ANTHROPIC_API_KEY=%s\\n' "\${ANTHROPIC_API_KEY-unset}"
} > "\$HOME/installer-$id.log"
[ ! -f "\$HOME/nonzero-$id" ] || exit 42
if [ ! -f "\$HOME/no-executable-$id" ]; then
  /bin/mkdir -p '${destination%/*}'
  printf '#!/bin/sh\\nexit 0\\n' > '$destination'
  /bin/chmod 700 '$destination'
fi
INSTALLER
STUB
chmod +x "$bin/id" "$bin/node" "$bin/npm" "$bin/setsid" "$bin/timeout" "$bin/curl"

export HSS_TEST_MODE=1
export HSS_AGENT_SYSTEM_PATH="$bin"
export DRY_RUN=false
export SUDO_PASSWORD='must-not-leak'
export OPENAI_API_KEY='must-not-leak'
export ANTHROPIC_API_KEY='must-not-leak'

# shellcheck source=setup.sh
source "$repo_root/setup.sh"
PATH=/usr/bin:/bin
HSS_RUN_ACTIVE=false
HSS_RUN_DIR="$fixture/run"
HSS_RUN_TMP_DIR="$HSS_RUN_DIR/tmp"
HSS_MANIFEST="$HSS_RUN_DIR/manifest.tsv"
mkdir -p "$HSS_RUN_TMP_DIR" "$HSS_RUN_DIR/backup"
: > "$HSS_MANIFEST"
: > "$HSS_RUN_DIR/meta"
resolve_package_registry
printf 'insecure\nheader = "Authorization: Bearer synthetic-value"\nurl = "https://example.invalid/unapproved"\n' > "$HOME/.curlrc"
HOME="$fixture/home [literal]#path" validate_official_agent_registry
printf 'ok - official metadata validation treats HOME literally, not as a regex\n'

reset_agent_state() {
  ROLE_SELECTIONS_LOADED=false
  PACKAGE_SELECTIONS_PREPARED=false
  SELECTED_PACMAN_LIST=()
  SELECTED_AUR_LIST=()
  SELECTED_ALL_PACKAGES=()
  AGENT_EXECUTABLES=()
  AGENT_EXECUTABLES_JSON='{}'
}

set_role_defaults
export ROLE_AGENT=pi
export ROLE_AGENT_PACKAGES='pi opencode claude-code codex-cli cursor-cli'
reset_agent_state
load_role_selections
prepare_package_selections
for prerequisite in curl nodejs npm tar gzip; do
  [[ " ${SELECTED_PACMAN_LIST[*]} " == *" $prerequisite "* ]]
done
[[ " ${SELECTED_PACMAN_LIST[*]} " != *' pi '* ]]
[[ " ${SELECTED_AUR_LIST[*]} " != *' opencode '* ]]
HSS_RUN_ACTIVE=true
install_official_agents

[[ $(wc -l < "$HOME/curl.log") -eq 5 ]]
for endpoint in \
  https://pi.dev/install.sh \
  https://opencode.ai/install \
  https://claude.ai/install.sh \
  https://chatgpt.com/codex/install.sh \
  https://cursor.com/install; do
  grep -Fqx "$endpoint" "$HOME/curl.log"
done
grep -Fq 'argv=<--no-modify-path>' "$HOME/installer-opencode.log"
grep -Fq "NPM_CONFIG_PREFIX=$HOME/.local" "$HOME/installer-pi.log"
grep -Fq 'CODEX_NON_INTERACTIVE=true' "$HOME/installer-codex-cli.log"
for log in "$HOME"/installer-*.log; do
  grep -Fq 'SUDO_PASSWORD=unset' "$log"
  grep -Fq 'OPENAI_API_KEY=unset' "$log"
  grep -Fq 'ANTHROPIC_API_KEY=unset' "$log"
done
grep -Fq '<--wait>' "$HOME/runner.log"
grep -Fq '<--kill-after=10s> <600s>' "$HOME/runner.log"
for id in pi codex-cli; do
  grep -Fq "<$bin/sh> <$HSS_RUN_TMP_DIR/agent-$id." "$HOME/runner.log"
done
for id in opencode claude-code cursor-cli; do
  grep -Fq "<$bin/bash> <$HSS_RUN_TMP_DIR/agent-$id." "$HOME/runner.log"
done
grep -Fq '<url=https://pi.dev/install.sh>' "$HOME/curl-argv.log"
grep -Fq '<url=https://cursor.com/install>' "$HOME/curl-argv.log"
grep -Fq "curl <--disable> <--proto> <=https> <--proto-redir> <=https> <--location>" "$HOME/curl-argv.log"
grep -Fq '<--connect-timeout> <10> <--max-time> <120> <--retry> <2>' "$HOME/curl-argv.log"
jq -e 'keys == ["claude-code","codex-cli","cursor-cli","opencode","pi"]
  and all(.[]; startswith("/"))' <<< "$AGENT_EXECUTABLES_JSON" >/dev/null
generate_roles_json
jq -e '.roles.agent.package == "pi"
  and ([.selected.agent[].package] == ["pi","opencode","claude-code","codex-cli","cursor-cli"])
  and (.agent_executables | keys == ["claude-code","codex-cli","cursor-cli","opencode","pi"])' \
  "$HOME/.config/hypr/roles.json" >/dev/null
printf 'ok - all official endpoints, argv, selected prerequisites, isolation, runner bounds, and executable metadata\n'

curl_lines=$(wc -l < "$HOME/curl.log")
install_official_agents
[[ $(wc -l < "$HOME/curl.log") -eq curl_lines ]]
printf 'ok - verified existing executables are reused without download or execution\n'

mv "$HOME/.local/bin/pi" "$fixture/pi-version-one"
ln -s "$fixture/pi-version-one" "$HOME/.local/bin/pi"
install_official_agents
[[ ${AGENT_EXECUTABLES[pi]} == "$HOME/.local/bin/pi" ]]
printf '#!/bin/sh\nexit 0\n' > "$fixture/pi-version-two"
chmod 700 "$fixture/pi-version-two"
ln -sfn "$fixture/pi-version-two" "$HOME/.local/bin/pi"
[[ $(readlink -f "${AGENT_EXECUTABLES[pi]}") == "$fixture/pi-version-two" ]]
[[ $(wc -l < "$HOME/curl.log") -eq curl_lines ]]
printf 'ok - executable metadata preserves stable vendor symlinks across self-updates\n'

saved_path=$PATH
custom_bin="$fixture/custom-bin"
mkdir -p "$custom_bin"
rm -f "$HOME/.local/bin/pi"
printf '#!/bin/sh\nexit 0\n' > "$custom_bin/pi"
chmod 700 "$custom_bin/pi"
PATH="$custom_bin:$PATH"
export ROLE_AGENT=pi
export ROLE_AGENT_PACKAGES=pi
install_official_agents
[[ ${AGENT_EXECUTABLES[pi]} == "$custom_bin/pi" ]]
[[ $(wc -l < "$HOME/curl.log") -eq curl_lines ]]
PATH=$saved_path
rm -rf "$custom_bin"
printf 'ok - nonstandard executable paths found on PATH are verified and recorded\n'

export ROLE_AGENT=
export ROLE_AGENT_PACKAGES=
install_official_agents
[[ $(wc -l < "$HOME/curl.log") -eq curl_lines ]]

rm -f "$HOME/.local/bin/pi"
export ROLE_AGENT=pi
export ROLE_AGENT_PACKAGES=pi
DRY_RUN=true
install_official_agents
DRY_RUN=false
[[ $(wc -l < "$HOME/curl.log") -eq curl_lines ]]
printf 'ok - None and dry-run perform no download or installer execution\n'

rm -f "$HOME/.opencode/bin/opencode" "$bin/tar"
export ROLE_AGENT=opencode
export ROLE_AGENT_PACKAGES=opencode
install_official_agents
[[ $(wc -l < "$HOME/curl.log") -eq curl_lines ]]
ln -s "$(command -v tar || printf /usr/bin/tar)" "$bin/tar"
printf 'ok - missing selected prerequisites skip before download\n'

rm -f "$HOME/.local/bin/codex" "$HOME/.local/bin/cursor-agent"
touch "$HOME/nonzero-codex-cli"
export ROLE_AGENT=codex-cli
export ROLE_AGENT_PACKAGES=codex-cli
install_official_agents
[[ ! -v 'AGENT_EXECUTABLES[codex-cli]' ]]
rm -f "$HOME/nonzero-codex-cli"
touch "$HOME/timeout-mode"
export ROLE_AGENT=cursor-cli
export ROLE_AGENT_PACKAGES=cursor-cli
install_official_agents
[[ ! -v 'AGENT_EXECUTABLES[cursor-cli]' ]]
rm -f "$HOME/timeout-mode"
printf 'ok - nonzero and timeout exits are bounded soft failures\n'

rm -f "$HOME/.local/bin/claude"
touch "$HOME/no-executable-claude-code"
export ROLE_AGENT=claude-code
export ROLE_AGENT_PACKAGES=claude-code
install_official_agents
[[ ! -v 'AGENT_EXECUTABLES[claude-code]' ]]
rm -f "$HOME/no-executable-claude-code"
printf 'ok - installer success without a verified executable is rejected\n'

rm -f "$HOME/.local/bin/pi"
touch "$HOME/root-mode"
export ROLE_AGENT=pi
export ROLE_AGENT_PACKAGES=pi
install_official_agents
[[ $(wc -l < "$HOME/curl.log") -eq $((curl_lines + 3)) ]]
rm -f "$HOME/root-mode"
printf 'ok - root execution is refused before download\n'

touch "$HOME/old-node"
install_official_agents
[[ $(wc -l < "$HOME/curl.log") -eq $((curl_lines + 3)) ]]
rm -f "$HOME/old-node"
printf 'ok - Pi requires Node.js 22.19.0 or newer before download\n'

invalid_registry="$fixture/packages-invalid.json"
jq '(.roles.agent.options[] | select(.package == "pi") | .installer.url) = "https://example.invalid/install"' \
  "$repo_root/packages.json" > "$invalid_registry"
PACKAGE_REGISTRY=$invalid_registry
if install_official_agents; then
  printf 'not ok - altered official installer metadata was accepted\n' >&2
  exit 1
fi
[[ $(wc -l < "$HOME/curl.log") -eq $((curl_lines + 3)) ]]
printf 'ok - altered installer metadata fails before side effects\n'
