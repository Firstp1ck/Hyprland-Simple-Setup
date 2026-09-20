#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT

cat > "$fixture/pass.sh" <<'PASS'
#!/usr/bin/env bash
set -euo pipefail
[[ -d $HOME && -d $XDG_CONFIG_HOME && -d $XDG_STATE_HOME && -d $XDG_RUNTIME_DIR ]]
[[ $PATH == "$HYPRLAND_SETUP_DIR/tests/stubs:"* ]]
printf 'ok - nested passing fixture saw isolated paths and stubs\n'
PASS
cat > "$fixture/fail.sh" <<'FAIL'
#!/usr/bin/env bash
printf 'intentional runner regression failure\n' >&2
exit 23
FAIL

set +e
runner_output=$("$repo_root/tests/run.sh" "$fixture/pass.sh" "$fixture/fail.sh" 2>&1)
runner_status=$?
set -e
[[ $runner_status -ne 0 ]]
grep -Fq 'ok - nested passing fixture saw isolated paths and stubs' <<<"$runner_output"
grep -Fq 'not ok - ' <<<"$runner_output"
grep -Fq '(exit 23)' <<<"$runner_output"
grep -Fq '1 test programs passed, 1 failed' <<<"$runner_output"
printf 'ok - test runner preserves isolation, continues after failure, and exits nonzero\n'

printf '{}\n' > "$fixture/invalid-packages.json"
set +e
checker_output=$(HSS_PACKAGES_JSON="$fixture/invalid-packages.json" \
  "$repo_root/tests/check_packages_json.sh" 2>&1)
checker_status=$?
set -e
[[ $checker_status -ne 0 ]]
grep -Fq 'not ok - package registry failed offline schema checks' <<<"$checker_output"

jq '.roles.launcher.options[0].namespace = "bad/name"' \
  "$repo_root/packages.json" > "$fixture/bad-token-packages.json"
set +e
checker_output=$(HSS_PACKAGES_JSON="$fixture/bad-token-packages.json" \
  "$repo_root/tests/check_packages_json.sh" 2>&1)
checker_status=$?
set -e
[[ $checker_status -ne 0 ]]
grep -Fq 'not ok - package registry failed offline schema checks' <<<"$checker_output"
printf 'ok - package registry checker rejects malformed roots and restricted tokens with slashes\n'
