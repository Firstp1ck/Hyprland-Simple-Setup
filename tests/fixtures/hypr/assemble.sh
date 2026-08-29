#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    printf 'usage: %s <fixture-home>\n' "$0" >&2
    exit 2
fi

fixture_home=$1
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
source_dir="$repo_root/dotfiles/.config/hypr"
target_dir="$fixture_home/.config/hypr"

mkdir -p -- "$fixture_home/.config"
cp -a -- "$source_dir" "$target_dir"
rm -rf -- "$target_dir/sources"
cp -a -- "$target_dir/sources_example" "$target_dir/sources"
