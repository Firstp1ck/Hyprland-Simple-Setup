#!/usr/bin/env bash
set -euo pipefail

# Hyprlock, Hypridle, and Hyprpaper do not provide an equivalent config verifier.
if ! command -v Hyprland >/dev/null 2>&1; then
    printf 'SKIPPED: Hyprland not installed\n'
    exit 3
fi

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture_root=$(mktemp -d)
trap 'rm -rf -- "$fixture_root"' EXIT

fixture_home="$fixture_root/home"
runtime_dir="$fixture_root/runtime"
output_file="$fixture_root/verify.out"
mkdir -p -- "$runtime_dir"
chmod 700 "$runtime_dir"

"$repo_root/tests/fixtures/hypr/assemble.sh" "$fixture_home"
config_file="$fixture_home/.config/hypr/hyprland.lua"

set +e
XDG_RUNTIME_DIR="$runtime_dir" HOME="$fixture_home" \
    Hyprland --verify-config --config "$config_file" >"$output_file" 2>&1
status=$?
set -e

cat "$output_file"

if [[ $status -ne 0 ]]; then
    printf 'Hyprland config verification exited with status %d\n' "$status" >&2
    exit 1
fi

if grep -Fq 'Config error' "$output_file"; then
    printf 'Hyprland config verification reported a Config error\n' >&2
    exit 1
fi
