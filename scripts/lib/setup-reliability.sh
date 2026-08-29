#!/usr/bin/env bash

# Run-scoped reliability primitives for setup.sh. This file is sourced.
HSS_STATE_ROOT=""
HSS_RUN_ID=""
HSS_RUN_DIR=""
HSS_RUN_TMP_DIR=""
HSS_MANIFEST=""
HSS_LOCK_FILE=""
HSS_LOCK_HOLDER_PID=""
HSS_KEEPALIVE_PID=""
HSS_RUN_ACTIVE=false
HSS_FINALIZING=false
HSS_ATOMIC_ACTIVE=false
HSS_PENDING_SIGNAL=""
declare -ag HSS_TMP_FILES=()

hss_valid_run_id() {
    [[ ${1:-} =~ ^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}$ ]]
}

hss_state_root() {
    printf '%s/hyprland-simple-setup' "${XDG_STATE_HOME:-$HOME/.local/state}"
}

hss_acquire_lock() {
    HSS_STATE_ROOT=$(hss_state_root)
    HSS_LOCK_FILE="$HSS_STATE_ROOT/lock"
    mkdir -p -- "$HSS_STATE_ROOT/runs"
    exec 9<>"$HSS_LOCK_FILE"
    if ! flock -n 9; then
        local holder pid=unknown started=unknown
        holder=$(cat -- "$HSS_LOCK_FILE" 2>/dev/null || true)
        [[ $holder =~ pid=([^[:space:]]+) ]] && pid=${BASH_REMATCH[1]}
        [[ $holder =~ started=([^[:space:]]+) ]] && started=${BASH_REMATCH[1]}
        printf 'Another setup run holds the lock (pid %s, started %s). Wait for it or remove %s if that process is gone.\n' "$pid" "$started" "$HSS_LOCK_FILE" >&2
        return 2
    fi
    printf 'pid=%s started=%s\n' "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$HSS_LOCK_FILE"
    local setup_pid=$$
    (
        while kill -0 "$setup_pid" 2>/dev/null; do
            sleep 1 9>&-
        done
    ) &
    HSS_LOCK_HOLDER_PID=$!
    exec 9>&-
}

hss_release_lock() {
    if [[ -n $HSS_LOCK_HOLDER_PID ]]; then
        kill "$HSS_LOCK_HOLDER_PID" 2>/dev/null || true
        wait "$HSS_LOCK_HOLDER_PID" 2>/dev/null || true
        HSS_LOCK_HOLDER_PID=""
    fi
}

hss_new_run_id() {
    local random
    random=$(head -c3 /dev/urandom | od -An -tx1 | tr -d ' \n')
    printf '%s-%s' "$(date -u +%Y%m%dT%H%M%SZ)" "$random"
}

hss_meta_append() {
    local key=$1 value=$2
    value=${value//$'\n'/ }
    value=${value//$'\r'/ }
    value=${value//$'\t'/ }
    printf '%s=%s\n' "$key" "$value" >> "$HSS_RUN_DIR/meta"
}

hss_meta_set() {
    local key=$1 value=$2 tmp
    [[ $HSS_RUN_ACTIVE == true ]] || return 0
    value=${value//$'\n'/ }
    value=${value//$'\r'/ }
    value=${value//$'\t'/ }
    make_tmp tmp meta.XXXXXX || return 1
    awk -F= -v key="$key" -v value="$value" 'BEGIN {updated=0} $1 == key {if (!updated) print key "=" value; updated=1; next} {print} END {if (!updated) print key "=" value}' "$HSS_RUN_DIR/meta" > "$tmp"
    mv -f -- "$tmp" "$HSS_RUN_DIR/meta"
}

hss_init_run() {
    local args=${1:-}
    HSS_STATE_ROOT=${HSS_STATE_ROOT:-$(hss_state_root)}
    HSS_RUN_ID=$(hss_new_run_id)
    HSS_RUN_DIR="$HSS_STATE_ROOT/runs/$HSS_RUN_ID"
    HSS_RUN_TMP_DIR="$HSS_RUN_DIR/tmp"
    HSS_MANIFEST="$HSS_RUN_DIR/manifest.tsv"
    mkdir -p -- "$HSS_RUN_TMP_DIR" "$HSS_RUN_DIR/backup"
    : > "$HSS_MANIFEST"
    : > "$HSS_RUN_DIR/log"
    : > "$HSS_RUN_DIR/meta"
    export LOG_FILE="$HSS_RUN_DIR/log"
    hss_meta_append start "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    hss_meta_append args "$args"
    local role var
    for role in BROWSER TERMINAL SHELL GUI_EDITOR TUI_EDITOR LAUNCHER; do
        var="ROLE_$role"
        hss_meta_append "$var" "${!var:-}"
    done
    hss_meta_append DRY_RUN "${DRY_RUN:-false}"
    HSS_RUN_ACTIVE=true
    trap 'hss_on_exit $?' EXIT
    trap 'hss_on_signal INT' INT
    trap 'hss_on_signal TERM' TERM
}

hss_cleanup() {
    local p
    if [[ -n $HSS_KEEPALIVE_PID ]]; then
        kill "$HSS_KEEPALIVE_PID" 2>/dev/null || true
        wait "$HSS_KEEPALIVE_PID" 2>/dev/null || true
        HSS_KEEPALIVE_PID=""
    fi
    for p in "${HSS_TMP_FILES[@]}" "$HSS_RUN_TMP_DIR"/*; do
        [[ -f $p && -n $HSS_RUN_TMP_DIR && $p == "$HSS_RUN_TMP_DIR"/* ]] && rm -f -- "$p"
    done
}

hss_finalize_run() {
    local status=${1:-0}
    [[ $HSS_RUN_ACTIVE == true ]] || return 0
    hss_meta_append end "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    hss_meta_append exit "$status"
    if hss_valid_run_id "$HSS_RUN_ID"; then
        printf '%s\n' "$HSS_RUN_ID" > "$HSS_STATE_ROOT/latest-run"
    fi
    HSS_RUN_ACTIVE=false
    hss_release_lock
}

hss_on_exit() {
    local status=$1
    [[ $HSS_FINALIZING == false ]] || return
    HSS_FINALIZING=true
    trap - EXIT INT TERM
    hss_cleanup
    hss_finalize_run "$status"
    return "$status"
}

hss_on_signal() {
    local signal=$1 number=15
    if [[ $HSS_ATOMIC_ACTIVE == true ]]; then
        HSS_PENDING_SIGNAL=$signal
        return 0
    fi
    [[ $signal == INT ]] && number=2
    trap - "$signal"
    hss_cleanup
    hss_finalize_run "$((128 + number))"
    kill -s "$signal" "$$"
}

make_tmp() {
    local output_var=$1 template=${2:-tmp.XXXXXX} path
    [[ $output_var =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 1
    [[ $HSS_RUN_ACTIVE == true && -d $HSS_RUN_TMP_DIR ]] || {
        printf 'Reliability run is not initialized\n' >&2
        return 1
    }
    path=$(mktemp "$HSS_RUN_TMP_DIR/$template") || return 1
    HSS_TMP_FILES+=("$path")
    printf -v "$output_var" '%s' "$path"
}

hss_refresh_sudo() {
    sudo -n -v >/dev/null 2>&1 && return 0
    [[ -n ${SUDO_PASSWORD:-} ]] || return 1
    printf '%s\n' "$SUDO_PASSWORD" | sudo -S -p '' -v >/dev/null 2>&1
}

hss_start_sudo_keepalive() {
    [[ -z $HSS_KEEPALIVE_PID ]] || return 0
    hss_refresh_sudo || {
        printf 'Unable to validate sudo credentials for unattended setup\n' >&2
        return 1
    }
    (
        while true; do
            sleep "${HSS_KEEPALIVE_INTERVAL:-50}" & wait $! || exit
            kill -0 "$$" 2>/dev/null || exit
            hss_refresh_sudo || exit
        done
    ) &
    HSS_KEEPALIVE_PID=$!
}

hss_path_is_approved() {
    local path=$1 home_config home_dotfiles
    home_config=$(readlink -m -- "$HOME/.config")
    home_dotfiles=$(readlink -m -- "$HOME/dotfiles/.config")
    case "$path" in
        "$home_config"/*|"$home_dotfiles"/*) return 0 ;;
    esac
    case "$path" in
        /etc/pam.d/login|/etc/pam.d/system-local-login|/etc/pacman.conf|/etc/systemd/system/grub-btrfsd.service.d/override.conf|/etc/sddm.conf.d/sddm.conf) return 0 ;;
    esac
    if [[ ${HSS_TEST_MODE:-0} == 1 && -n ${HSS_TEST_ETC_ROOT:-} ]]; then
        case "$path" in
            "$HSS_TEST_ETC_ROOT/pam.d/login"|"$HSS_TEST_ETC_ROOT/pam.d/system-local-login"|"$HSS_TEST_ETC_ROOT/pacman.conf"|"$HSS_TEST_ETC_ROOT/systemd/system/grub-btrfsd.service.d/override.conf"|"$HSS_TEST_ETC_ROOT/sddm.conf.d/sddm.conf") return 0 ;;
        esac
    fi
    return 1
}

hss_path_is_privileged() {
    [[ $1 == /etc/* ]] && return 0
    [[ ${HSS_TEST_MODE:-0} == 1 && -n ${HSS_TEST_ETC_ROOT:-} && $1 == "$HSS_TEST_ETC_ROOT"/* ]]
}

hss_resolve_destination() {
    local dest=$1 parent resolved
    [[ $dest == /* ]] || dest=$(readlink -m -- "$PWD/$dest")
    if [[ -L $dest ]]; then
        resolved=$(readlink -f -- "$dest") || return 1
    elif [[ -e $dest ]]; then
        resolved=$(readlink -f -- "$dest") || return 1
    else
        parent=$(readlink -f -- "$(dirname -- "$dest")") || return 1
        resolved="$parent/$(basename -- "$dest")"
    fi
    hss_path_is_approved "$resolved" || {
        printf 'Refusing setup-managed write outside approved roots: %s\n' "$resolved" >&2
        return 1
    }
    printf '%s\n' "$resolved"
}

hss_sha256() {
    sha256sum -- "$1" | awk '{print $1}'
}

hss_manifest_find() {
    local path=$1
    awk -F '\t' -v path="$path" '$2 == path { print; found=1 } END { exit !found }' "$HSS_MANIFEST"
}

hss_manifest_replace_after() {
    local path=$1 after=$2 tmp
    make_tmp tmp manifest.XXXXXX || return 1
    awk -F '\t' -v OFS='\t' -v path="$path" -v after="$after" '$2 == path {$4=after} {print}' "$HSS_MANIFEST" > "$tmp"
    mv -f -- "$tmp" "$HSS_MANIFEST"
}

hss_manifest_prepare() {
    local requested=$1 resolved=$2 candidate=$3 kind before backup_rel backup_abs key requested_lexical
    if hss_manifest_find "$resolved" >/dev/null 2>&1; then
        return 0
    fi
    if [[ -e $resolved ]]; then
        before=$(hss_sha256 "$resolved") || return 1
        kind=modified
        requested_lexical=$(realpath -ms -- "$requested")
        [[ $requested_lexical != "$resolved" ]] && kind=symlink-target
        key=$(printf '%s' "$resolved" | sha256sum | awk '{print $1}')
        backup_rel="backup/$key"
        backup_abs="$HSS_RUN_DIR/$backup_rel"
        if hss_path_is_privileged "$resolved"; then
            sudo cp --preserve=mode,ownership -- "$resolved" "$backup_abs" && sudo chown "$(id -u):$(id -g)" "$backup_abs"
        else
            cp --preserve=mode -- "$resolved" "$backup_abs"
        fi || return 1
    else
        kind=created
        before=-
        backup_rel=-
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$kind" "$resolved" "$before" "$candidate" "$backup_rel" >> "$HSS_MANIFEST"
}

hss_remove_atomic_tmp() {
    local path=$1 privileged=$2
    [[ -n $path && $(basename -- "$path") == .hss-atomic.* ]] || return 0
    if [[ $privileged == true ]]; then
        sudo rm -f -- "$path" 2>/dev/null || true
    else
        rm -f -- "$path" 2>/dev/null || true
    fi
}

hss_finish_atomic() {
    local pending=$HSS_PENDING_SIGNAL
    HSS_ATOMIC_ACTIVE=false
    HSS_PENDING_SIGNAL=""
    [[ -z $pending ]] || hss_on_signal "$pending"
}

hss_fail_atomic() {
    hss_remove_atomic_tmp "$1" "$2"
    hss_finish_atomic
    return 1
}

write_file_atomic() {
    local dest=$1 source=$2 reason=${3:-setup-managed update} resolved candidate dir atomic_tmp="" privileged=false
    if is_dry_run; then
        local kind=create
        [[ -e $dest || -L $dest ]] && kind=modify
        log_dry_run_operation write_file_atomic "would $kind $dest: $reason"
        return 0
    fi
    [[ -f $source ]] || { printf 'Atomic source is not a regular file: %s\n' "$source" >&2; return 1; }
    resolved=$(hss_resolve_destination "$dest") || return 1
    candidate=$(hss_sha256 "$source") || return 1
    dir=$(dirname -- "$resolved")
    hss_path_is_privileged "$resolved" && privileged=true
    hss_manifest_prepare "$dest" "$resolved" "$candidate" || return 1
    HSS_ATOMIC_ACTIVE=true
    HSS_PENDING_SIGNAL=""
    if $privileged; then
        atomic_tmp=$(sudo mktemp "$dir/.hss-atomic.XXXXXX") || { hss_finish_atomic; return 1; }
        if [[ -e $resolved ]]; then
            sudo cp --preserve=mode,ownership -- "$source" "$atomic_tmp" || { hss_fail_atomic "$atomic_tmp" true; return 1; }
            sudo chmod --reference="$resolved" "$atomic_tmp" || { hss_fail_atomic "$atomic_tmp" true; return 1; }
            sudo chown --reference="$resolved" "$atomic_tmp" || { hss_fail_atomic "$atomic_tmp" true; return 1; }
        else
            sudo cp -- "$source" "$atomic_tmp" || { hss_fail_atomic "$atomic_tmp" true; return 1; }
            sudo chmod 0644 "$atomic_tmp" || { hss_fail_atomic "$atomic_tmp" true; return 1; }
        fi
        sudo sync -f "$atomic_tmp" || { hss_fail_atomic "$atomic_tmp" true; return 1; }
        sudo mv -f -- "$atomic_tmp" "$resolved" || { hss_fail_atomic "$atomic_tmp" true; return 1; }
    else
        mkdir -p -- "$dir"
        atomic_tmp=$(mktemp "$dir/.hss-atomic.XXXXXX") || { hss_finish_atomic; return 1; }
        if [[ -e $resolved ]]; then
            cp --preserve=mode -- "$source" "$atomic_tmp" || { hss_fail_atomic "$atomic_tmp" false; return 1; }
            chmod --reference="$resolved" "$atomic_tmp" || { hss_fail_atomic "$atomic_tmp" false; return 1; }
        else
            cp -- "$source" "$atomic_tmp" || { hss_fail_atomic "$atomic_tmp" false; return 1; }
            chmod 0644 "$atomic_tmp" || { hss_fail_atomic "$atomic_tmp" false; return 1; }
        fi
        sync -f "$atomic_tmp" || { hss_fail_atomic "$atomic_tmp" false; return 1; }
        mv -f -- "$atomic_tmp" "$resolved" || { hss_fail_atomic "$atomic_tmp" false; return 1; }
    fi
    local manifest_status=0
    hss_manifest_replace_after "$resolved" "$candidate" || manifest_status=$?
    hss_finish_atomic
    return "$manifest_status"
}

edit_file_atomic() {
    local dest=$1 reason=$2
    shift 2
    local tmp
    make_tmp tmp edit.XXXXXX || return 1
    if is_dry_run; then
        write_file_atomic "$dest" "$tmp" "$reason"
        return 0
    fi
    [[ -f $dest ]] || : > "$tmp"
    if [[ -f $dest ]]; then
        "$@" < "$dest" > "$tmp" || return 1
    else
        "$@" < /dev/null > "$tmp" || return 1
    fi
    write_file_atomic "$dest" "$tmp" "$reason"
}

hss_validate_meta() {
    local meta=$1
    [[ -f $meta && ! -L $meta ]] || { printf 'Rollback refused: missing meta\n' >&2; return 1; }
    if grep -q '[[:cntrl:]]' "$meta"; then
        printf 'Rollback refused: control character in meta\n' >&2
        return 1
    fi
    if ! awk -F= 'NF >= 2 && $1 ~ /^[A-Z_]+$|^(start|end|exit|args)$/ {next} {exit 1}' "$meta"; then
        printf 'Rollback refused: malformed meta field\n' >&2
        return 1
    fi
    if ! grep -q '^start=' "$meta" || ! grep -q '^end=' "$meta" || ! grep -Eq '^exit=[0-9]+$' "$meta"; then
        printf 'Rollback refused: malformed or incomplete meta\n' >&2
        return 1
    fi
}

hss_validate_manifest() {
    local source_run=$1
    local manifest="$source_run/manifest.tsv" backup_root path kind before after backup fields canonical backup_abs actual
    [[ -f $manifest && ! -L $manifest ]] || { printf 'Rollback refused: missing manifest\n' >&2; return 1; }
    backup_root=$(readlink -f -- "$source_run/backup") || return 1
    declare -A seen=()
    local line_number=0
    while IFS= read -r line || [[ -n $line ]]; do
        line_number=$((line_number + 1))
        [[ $line != *$'\r'* ]] || { printf 'Rollback refused: control character in manifest line %d\n' "$line_number" >&2; return 1; }
        fields=$(awk -F '\t' '{print NF}' <<< "$line")
        [[ $fields == 5 ]] || { printf 'Rollback refused: manifest line %d does not have five columns\n' "$line_number" >&2; return 1; }
        IFS=$'\t' read -r kind path before after backup <<< "$line"
        if printf '%s' "$kind$path$before$after$backup" | grep -q '[[:cntrl:]]'; then
            printf 'Rollback refused: control character in manifest line %d\n' "$line_number" >&2
            return 1
        fi
        [[ $kind =~ ^(created|modified|symlink-target)$ ]] || { printf 'Rollback refused: invalid kind on line %d\n' "$line_number" >&2; return 1; }
        [[ $path == /* && $path != *$'\t'* && $path != *$'\n'* ]] || { printf 'Rollback refused: invalid path on line %d\n' "$line_number" >&2; return 1; }
        canonical=$(readlink -m -- "$path")
        [[ $canonical == "$path" ]] || { printf 'Rollback refused: non-canonical destination %s\n' "$path" >&2; return 1; }
        hss_path_is_approved "$path" || { printf 'Rollback refused: out-of-scope destination %s\n' "$path" >&2; return 1; }
        [[ -z ${seen[$path]+x} ]] || { printf 'Rollback refused: duplicate destination %s\n' "$path" >&2; return 1; }
        seen[$path]=1
        [[ $after =~ ^[0-9a-f]{64}$ ]] || { printf 'Rollback refused: invalid after digest on line %d\n' "$line_number" >&2; return 1; }
        if [[ $kind == created ]]; then
            [[ $before == - && $backup == - ]] || { printf 'Rollback refused: invalid created row on line %d\n' "$line_number" >&2; return 1; }
        else
            [[ $before =~ ^[0-9a-f]{64}$ && $backup != - && $backup != /* && $backup != *..* ]] || { printf 'Rollback refused: invalid backup fields on line %d\n' "$line_number" >&2; return 1; }
            [[ -f $source_run/$backup && ! -L $source_run/$backup ]] || { printf 'Rollback refused: missing backup on line %d\n' "$line_number" >&2; return 1; }
            backup_abs=$(readlink -f -- "$source_run/$backup" 2>/dev/null) || { printf 'Rollback refused: missing backup on line %d\n' "$line_number" >&2; return 1; }
            [[ $backup_abs == "$backup_root"/* ]] || { printf 'Rollback refused: backup traversal on line %d\n' "$line_number" >&2; return 1; }
            actual=$(hss_sha256 "$backup_abs") || return 1
            [[ $actual == "$before" ]] || { printf 'Rollback refused: corrupted backup on line %d\n' "$line_number" >&2; return 1; }
        fi
    done < "$manifest"
}

hss_rollback() {
    local run_id=$1 runs_root source_run source_canonical expected manifest kind path before after backup current mismatch=false
    hss_valid_run_id "$run_id" || { printf 'Rollback refused: invalid run ID %s\n' "$run_id" >&2; return 1; }
    runs_root=$(readlink -m -- "$(hss_state_root)/runs")
    source_run="$runs_root/$run_id"
    source_canonical=$(readlink -f -- "$source_run" 2>/dev/null) || { printf 'Rollback refused: run not found\n' >&2; return 1; }
    expected="$runs_root/$run_id"
    [[ $source_canonical == "$expected" ]] || { printf 'Rollback refused: run directory traversal\n' >&2; return 1; }
    hss_validate_meta "$source_run/meta" || return 1
    hss_validate_manifest "$source_run" || return 1
    manifest="$source_run/manifest.tsv"
    while IFS=$'\t' read -r kind path before after backup; do
        if [[ -f $path ]]; then current=$(hss_sha256 "$path"); else current=missing; fi
        if [[ $current != "$after" ]]; then
            printf 'Digest mismatch: %s (expected %s, found %s)\n' "$path" "$after" "$current" >&2
            mismatch=true
        fi
    done < "$manifest"
    if $mismatch; then
        if [[ ${NON_INTERACTIVE:-false} == true || ! -t 0 ]]; then
            printf 'Rollback refused: digest mismatch requires interactive confirmation\n' >&2
            return 1
        fi
        read -rp 'Overwrite files changed since setup? (y/N): ' answer
        [[ $answer =~ ^[Yy]$ ]] || { printf 'Rollback cancelled\n' >&2; return 1; }
    fi
    while IFS=$'\t' read -r kind path before after backup; do
        if [[ $kind == created ]]; then
            rm -f -- "$path"
        else
            write_file_atomic "$path" "$source_run/$backup" "rollback $run_id"
        fi
    done < "$manifest"
    printf 'Rollback completed for run %s\n' "$run_id"
}

hss_list_runs() {
    local runs_root run id start end status
    runs_root="$(hss_state_root)/runs"
    [[ -d $runs_root ]] || return 0
    for run in "$runs_root"/*; do
        [[ -d $run ]] || continue
        id=$(basename -- "$run")
        hss_valid_run_id "$id" || continue
        start=$(sed -n 's/^start=//p' "$run/meta" 2>/dev/null | head -n1)
        end=$(sed -n 's/^end=//p' "$run/meta" 2>/dev/null | tail -n1)
        status=$(sed -n 's/^exit=//p' "$run/meta" 2>/dev/null | tail -n1)
        printf '%s\tstart=%s\tend=%s\texit=%s\n' "$id" "${start:--}" "${end:--}" "${status:--}"
    done
}

hss_begin_run() {
    local args=${1:-}
    hss_acquire_lock || return $?
    hss_init_run "$args"
}
