#!/usr/bin/env bash

# Safe runner for the fixed official coding-agent installer registry.
# shellcheck disable=SC2034 # Entries are consumed through generated runtime JSON.
declare -Ag AGENT_EXECUTABLES=()
AGENT_EXECUTABLES_JSON='{}'

agent_contract() {
    local id=$1
    case "$id" in
        pi)
            AGENT_EXECUTABLE=pi
            AGENT_INSTALLER_URL=https://pi.dev/install.sh
            AGENT_INSTALLER_SHELL='sh'
            AGENT_INSTALLER_ARGS=()
            AGENT_BINARY_PATHS=("$HOME/.local/bin/pi")
            AGENT_EXTRA_PACKAGES=(curl nodejs npm)
            ;;
        opencode)
            AGENT_EXECUTABLE=opencode
            AGENT_INSTALLER_URL=https://opencode.ai/install
            AGENT_INSTALLER_SHELL=bash
            AGENT_INSTALLER_ARGS=(--no-modify-path)
            AGENT_BINARY_PATHS=("$HOME/.opencode/bin/opencode")
            AGENT_EXTRA_PACKAGES=(curl tar gzip)
            ;;
        claude-code)
            AGENT_EXECUTABLE=claude
            AGENT_INSTALLER_URL=https://claude.ai/install.sh
            AGENT_INSTALLER_SHELL=bash
            AGENT_INSTALLER_ARGS=()
            AGENT_BINARY_PATHS=("$HOME/.local/bin/claude")
            AGENT_EXTRA_PACKAGES=(curl)
            ;;
        codex-cli)
            AGENT_EXECUTABLE=codex
            AGENT_INSTALLER_URL=https://chatgpt.com/codex/install.sh
            AGENT_INSTALLER_SHELL='sh'
            AGENT_INSTALLER_ARGS=()
            AGENT_BINARY_PATHS=("$HOME/.local/bin/codex")
            AGENT_EXTRA_PACKAGES=(curl tar gzip)
            ;;
        cursor-cli)
            AGENT_EXECUTABLE=cursor-agent
            AGENT_INSTALLER_URL=https://cursor.com/install
            AGENT_INSTALLER_SHELL=bash
            AGENT_INSTALLER_ARGS=()
            AGENT_BINARY_PATHS=("$HOME/.local/bin/cursor-agent")
            AGENT_EXTRA_PACKAGES=(curl tar gzip)
            ;;
        *) return 1 ;;
    esac
}

agent_controlled_path() {
    if [[ ${HSS_TEST_MODE:-0} == 1 && -n ${HSS_AGENT_SYSTEM_PATH:-} ]]; then
        printf '%s/.local/bin:%s/.opencode/bin:%s' "$HOME" "$HOME" "$HSS_AGENT_SYSTEM_PATH"
    else
        printf '%s/.local/bin:%s/.opencode/bin:/usr/local/bin:/usr/bin:/bin' "$HOME" "$HOME"
    fi
}

agent_find_command() {
    local executable=$1 controlled_path
    controlled_path=$(agent_controlled_path) || return 1
    PATH=$controlled_path command -v -- "$executable" 2>/dev/null
}

agent_resolve_executable() {
    local id=$1 candidate resolved readlink_cmd
    agent_contract "$id" || return 1
    readlink_cmd=$(agent_find_command readlink) || return 1
    for candidate in "${AGENT_BINARY_PATHS[@]}"; do
        if [[ $candidate == /* && -f $candidate && -x $candidate ]]; then
            resolved=$("$readlink_cmd" -f -- "$candidate") || continue
            [[ -f $resolved && -x $resolved ]] || continue
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    candidate=$(command -v -- "$AGENT_EXECUTABLE" 2>/dev/null || true)
    if [[ $candidate != /* || ! -f $candidate || ! -x $candidate ]]; then
        candidate=$(agent_find_command "$AGENT_EXECUTABLE") || return 1
    fi
    [[ $candidate == /* && -f $candidate && -x $candidate ]] || return 1
    resolved=$("$readlink_cmd" -f -- "$candidate") || return 1
    [[ -f $resolved && -x $resolved ]] || return 1
    # Keep vendor-managed symlink paths so self-updates do not pin triage to old versions.
    printf '%s\n' "$candidate"
}

agent_registry_contract_valid() {
    local id=$1 expected actual args_json extras_json path
    local -a symbolic_paths=()
    agent_contract "$id" || return 1
    for path in "${AGENT_BINARY_PATHS[@]}"; do
        symbolic_paths+=("{HOME}${path#"$HOME"}")
    done
    args_json='[]'
    if ((${#AGENT_INSTALLER_ARGS[@]} > 0)); then
        args_json=$(printf '%s\n' "${AGENT_INSTALLER_ARGS[@]}" | jq -Rsc 'split("\n")[:-1]') || return 1
    fi
    extras_json=$(printf '%s\n' "${AGENT_EXTRA_PACKAGES[@]}" | jq -Rsc 'split("\n")[:-1]') || return 1
    expected=$(jq -cn \
        --arg package "$id" \
        --arg executable "$AGENT_EXECUTABLE" \
        --arg url "$AGENT_INSTALLER_URL" \
        --arg shell "$AGENT_INSTALLER_SHELL" \
        --argjson args "$args_json" \
        --argjson paths "$(printf '%s\n' "${symbolic_paths[@]}" | jq -Rsc 'split("\n")[:-1]')" \
        --argjson extras "$extras_json" \
        '{package:$package, executable:$executable, url:$url, shell:$shell, args:$args, paths:$paths, extras:$extras}') || return 1
    actual=$(jq -ce --arg id "$id" '
        .roles.agent.options[] | select(.package == $id)
        | {package, executable, url:.installer.url, shell:.installer.shell,
           args:.installer.args, paths:.binary_paths, extras:.extra_packages}
    ' "$PACKAGE_REGISTRY") || return 1
    [[ $actual == "$expected" ]]
}

validate_official_agent_registry() {
    local id
    jq -e '
        (.official_packages | [to_entries[].value[]] | sort)
          == ["claude-code", "codex-cli", "cursor-cli", "opencode", "pi"]
        and (.roles.agent.selection == "multiple")
        and (.roles.agent.required == false)
        and (.roles.agent.default == "pi")
        and ([.roles.agent.options[].package] | sort)
          == ["claude-code", "codex-cli", "cursor-cli", "opencode", "pi"]
        and all(.roles.agent.options[]; .source == "official")
    ' "$PACKAGE_REGISTRY" >/dev/null || return 1
    for id in pi opencode claude-code codex-cli cursor-cli; do
        agent_registry_contract_valid "$id" || return 1
    done
}

agent_soft_failure() {
    local message=$1
    if declare -F record_soft_error >/dev/null; then
        record_soft_error install_official_agents "$message"
    fi
    if declare -F print_warning >/dev/null; then
        print_warning "$message"
    else
        printf 'Warning: %s\n' "$message" >&2
    fi
}

agent_require_runner() {
    local program=$1
    if ! agent_find_command "$program" >/dev/null; then
        agent_soft_failure "Cannot install coding agents safely: required runner '$program' is unavailable"
        return 1
    fi
}

agent_required_commands_available() {
    local id=$1 program
    local -a required=(curl)
    case "$id" in
        pi) required+=(node npm) ;;
        opencode|codex-cli|cursor-cli) required+=(tar gzip) ;;
        claude-code) ;;
        *) return 1 ;;
    esac
    for program in "${required[@]}"; do
        if ! agent_find_command "$program" >/dev/null; then
            agent_soft_failure "Cannot install $id: selected prerequisite '$program' is unavailable"
            return 1
        fi
    done
}

agent_pi_runtime_valid() {
    local node npm
    node=$(agent_find_command node) || return 1
    npm=$(agent_find_command npm) || return 1
    "$node" -e 'const [a,b,c]=process.versions.node.split(".").map(Number); process.exit(a>22 || (a===22 && (b>19 || (b===19 && c>=0))) ? 0 : 1)' \
        </dev/null >/dev/null 2>&1 && [[ -x $npm ]]
}

agent_print_bounded_log() {
    local log=$1 tail
    [[ -s $log ]] || return 0
    tail=$(agent_find_command tail) || return 0
    printf '%s\n' '--- official installer output (last 40 lines) ---'
    "$tail" -n 40 -- "$log"
    printf '%s\n' '--- end official installer output ---'
}

agent_download_installer() {
    local destination=$1 controlled_path curl env_cmd
    controlled_path=$(agent_controlled_path) || return 1
    curl=$(agent_find_command curl) || return 1
    env_cmd=$(agent_find_command env) || return 1
    "$env_cmd" -i \
        HOME="$HOME" PATH="$controlled_path" USER="$AGENT_RUN_USER" LOGNAME="$AGENT_RUN_USER" \
        SHELL=/bin/sh LANG=C.UTF-8 LC_ALL=C.UTF-8 TMPDIR="$HSS_RUN_TMP_DIR" \
        "$curl" --disable --proto '=https' --proto-redir '=https' --location --fail --show-error --silent \
        --connect-timeout 10 --max-time 120 --retry 2 --retry-delay 1 --retry-max-time 180 \
        --output "$destination" "$AGENT_INSTALLER_URL" </dev/null
}

agent_run_installer() {
    local script=$1 log=$2 controlled_path env_cmd setsid timeout interpreter status=0
    controlled_path=$(agent_controlled_path) || return 1
    env_cmd=$(agent_find_command env) || return 1
    setsid=$(agent_find_command setsid) || return 1
    timeout=$(agent_find_command timeout) || return 1
    interpreter=$(agent_find_command "$AGENT_INSTALLER_SHELL") || return 1

    local -a child_env=(
        HOME="$HOME"
        PATH="$controlled_path"
        USER="$AGENT_RUN_USER"
        LOGNAME="$AGENT_RUN_USER"
        SHELL=/bin/sh
        LANG=C.UTF-8
        LC_ALL=C.UTF-8
        TMPDIR="$HSS_RUN_TMP_DIR"
        NO_COLOR=1
    )
    [[ $AGENT_ID != pi ]] || child_env+=(NPM_CONFIG_PREFIX="$HOME/.local")
    [[ $AGENT_ID != codex-cli ]] || child_env+=(CODEX_NON_INTERACTIVE=true)

    "$env_cmd" -i "${child_env[@]}" \
        "$setsid" --wait "$timeout" --kill-after=10s 600s \
        "$interpreter" "$script" "${AGENT_INSTALLER_ARGS[@]}" \
        </dev/null >"$log" 2>&1 || status=$?
    agent_print_bounded_log "$log"
    return "$status"
}

agent_record_executable() {
    local id=$1 path=$2
    AGENT_EXECUTABLES[$id]=$path
    AGENT_EXECUTABLES_JSON=$(jq -cn \
        --argjson current "$AGENT_EXECUTABLES_JSON" --arg id "$id" --arg path "$path" \
        '$current + {($id): $path}') || return 1
}

install_official_agents() {
    local id resolved script log status
    # shellcheck disable=SC2034 # Reset before rebuilding generated runtime JSON.
    AGENT_EXECUTABLES=()
    AGENT_EXECUTABLES_JSON='{}'
    [[ -n ${ROLE_AGENT_PACKAGES:-} ]] || {
        if declare -F print_message >/dev/null; then
            print_message "No coding agents selected; skipping official installers"
        fi
        return 0
    }
    validate_official_agent_registry || {
        if declare -F print_error >/dev/null; then
            print_error "Official coding-agent registry does not match the approved installer allowlist"
        fi
        return 1
    }

    if declare -F is_dry_run >/dev/null && is_dry_run; then
        for id in $ROLE_AGENT_PACKAGES; do
            agent_contract "$id" || return 1
            log_dry_run_operation install_official_agents "Would reuse $AGENT_EXECUTABLE if present, otherwise download $AGENT_INSTALLER_URL and run it as the normal user"
        done
        return 0
    fi

    if ((EUID == 0)); then
        agent_soft_failure "Refusing to run official coding-agent installers as root"
        return 0
    fi
    local id_command
    id_command=$(agent_find_command id) || {
        agent_soft_failure "Cannot determine the normal user safely: required runner 'id' is unavailable"
        return 0
    }
    AGENT_RUN_USER=$("$id_command" -un) || return 1
    if [[ $("$id_command" -u) -eq 0 ]]; then
        agent_soft_failure "Refusing to run official coding-agent installers as root"
        return 0
    fi
    for program in env setsid timeout curl tail readlink; do
        agent_require_runner "$program" || return 0
    done

    for id in $ROLE_AGENT_PACKAGES; do
        AGENT_ID=$id
        agent_contract "$id" || return 1
        if resolved=$(agent_resolve_executable "$id"); then
            agent_record_executable "$id" "$resolved" || return 1
            print_message "Reusing existing $id executable: $resolved"
            continue
        fi
        agent_require_runner "$AGENT_INSTALLER_SHELL" || continue
        agent_required_commands_available "$id" || continue
        if [[ $id == pi ]] && ! agent_pi_runtime_valid; then
            agent_soft_failure "Pi requires Node.js 22.19.0 or newer and npm; skipping its official installer"
            continue
        fi
        make_tmp script "agent-$id.XXXXXX.sh" || return 1
        make_tmp log "agent-$id-log.XXXXXX" || return 1
        chmod 600 -- "$script" "$log" || return 1
        print_message "Downloading approved $id installer from $AGENT_INSTALLER_URL"
        if ! agent_download_installer "$script"; then
            agent_soft_failure "Failed to download the approved $id installer"
            continue
        fi
        status=0
        agent_run_installer "$script" "$log" || status=$?
        if ((status != 0)); then
            agent_soft_failure "Official $id installer failed with exit $status"
            continue
        fi
        if ! resolved=$(agent_resolve_executable "$id"); then
            agent_soft_failure "Official $id installer exited successfully but no verified executable was found"
            continue
        fi
        agent_record_executable "$id" "$resolved" || return 1
        print_message "Installed $id executable: $resolved"
    done
    return 0
}
