#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/shell/roles_testlib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/roles_testlib.sh"

for test in test_system_update.sh test_launch_system_update.sh test_confirm_system_update.sh test_update_maintenance_action.sh; do
    bash "$repo_root/dotfiles/.config/waybar/tests/$test"
done
python "$repo_root/dotfiles/.config/waybar/tests/test_update_menu_contract.py"

fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
setup_role_fixture "$fixture"
set_role_defaults
scripts="$HOME/dotfiles/.config/waybar/scripts"
# Simulate an existing installation with the unconfigured launcher and no backend.
printf '#!/usr/bin/env bash\necho old-launcher\n' > "$scripts/launch_system_update.sh"
rm -- "$scripts/system_update.sh"
DRY_RUN=true HSS_RELIABILITY_ACTION=sync-managed \
    "$repo_root/setup.sh" --test-scenario reliability > "$fixture/dry-run.log"
grep -Fq old-launcher "$scripts/launch_system_update.sh"
[[ ! -e "$scripts/system_update.sh" ]]
HSS_RELIABILITY_ACTION=sync-managed \
    "$repo_root/setup.sh" --test-scenario reliability > "$fixture/sync.log"
for script in confirm_system_update.sh launch_system_update.sh system_update.sh update_maintenance_action.sh; do
    cmp "$repo_root/dotfiles/.config/waybar/scripts/$script" "$scripts/$script"
    [[ -x "$scripts/$script" ]]
done
printf 'ok - managed-file sync repairs existing update scripts; dry-run leaves them unchanged\n'
