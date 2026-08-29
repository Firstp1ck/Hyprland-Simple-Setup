#!/usr/bin/env bash
# Preserve SwayNC status while documenting the module's two click actions.

set -euo pipefail

readonly HINT="Left click: notifications • Right click: do not disturb"

swaync-client -swb \
    | jq --unbuffered --compact-output --arg hint "$HINT" '
        (.tooltip // "" | tostring) as $current
        | .tooltip = (
            if ($current | length) == 0 then
                $hint
            else
                $current + "\n\n" + $hint
            end
        )
    '
