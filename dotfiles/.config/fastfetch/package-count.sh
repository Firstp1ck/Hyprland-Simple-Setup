#!/usr/bin/env bash

count_packages() {
    local output
    if ! output=$(pacman "$@" 2>/dev/null); then
        return 1
    fi

    if [[ -z $output ]]; then
        printf '0'
    else
        printf '%s\n' "$output" | awk 'NF { count++ } END { print count + 0 }'
    fi
}

if ! command -v pacman >/dev/null 2>&1; then
    printf 'unavailable\n'
    exit 0
fi

if ! native_count=$(count_packages -Qnq) || ! foreign_count=$(count_packages -Qmq); then
    printf 'unavailable\n'
    exit 0
fi

# Pacman records repository packages as native and AUR/local builds as foreign.
total_count=$((native_count + foreign_count))
printf '%d (pacman: %d, AUR/foreign: %d)\n' "$total_count" "$native_count" "$foreign_count"
