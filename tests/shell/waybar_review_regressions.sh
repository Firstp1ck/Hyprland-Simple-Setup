#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"

PYTHONDONTWRITEBYTECODE=1 python3 "$repo_root/dotfiles/.config/waybar/tests/test_review_regressions.py"

fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
setup_role_fixture "$fixture"
scripts="$HOME/dotfiles/.config/waybar/scripts"
for file in brightness.sh waybar_launch.sh; do
    printf '#!/bin/bash\necho stale\n' > "$scripts/$file"
done
rm -- "$scripts/hss_jsonc.py"
DRY_RUN=true HSS_RELIABILITY_ACTION=sync-managed \
    "$repo_root/setup.sh" --test-scenario reliability > "$fixture/dry-run.log"
[[ ! -e $scripts/hss_jsonc.py ]]
grep -Fq stale "$scripts/waybar_launch.sh"
HSS_RELIABILITY_ACTION=sync-managed \
    "$repo_root/setup.sh" --test-scenario reliability > "$fixture/sync.log"
for file in brightness.sh waybar_launch.sh hss_jsonc.py; do
    cmp "$repo_root/dotfiles/.config/waybar/scripts/$file" "$scripts/$file"
done
[[ -x $scripts/brightness.sh && -x $scripts/waybar_launch.sh ]]
printf '{ // installed JSONC validator\n "clock": {},\n}\n' > "$fixture/config.jsonc"
python3 "$scripts/hss_jsonc.py" "$fixture/config.jsonc"
printf 'ok - existing installs receive brightness, launcher, and shared JSONC fixes; dry-run is non-mutating\n'
