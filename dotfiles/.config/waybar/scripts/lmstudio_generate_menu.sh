#!/usr/bin/env bash
# Generate LM Studio menu XML and matching Waybar actions from installed models.

set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar"
MENU_FILE="${LMSTUDIO_MENU_FILE:-$CACHE_DIR/lmstudio_menu.xml}"
CONFIG_SNIPPET_FILE="${LMSTUDIO_MENU_ACTIONS_FILE:-$CACHE_DIR/lmstudio_menu_actions.jsonc}"

mkdir -p "$CACHE_DIR" "$(dirname "$MENU_FILE")" "$(dirname "$CONFIG_SNIPPET_FILE")"

if [[ -d "$HOME/.lmstudio/bin" ]]; then
    export PATH="$PATH:$HOME/.lmstudio/bin"
fi

write_empty_menu() {
    cat >"$MENU_FILE" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<interface>
  <object class="GtkMenu" id="menu">
    <child>
      <object class="GtkMenuItem" id="no-models">
        <property name="label">No models available</property>
        <property name="sensitive">False</property>
      </object>
    </child>
  </object>
</interface>
EOF

    cat >"$CONFIG_SNIPPET_FILE" <<'EOF'
// Auto-generated menu actions for LM Studio models
// This file should be included in waybar config.jsonc menu-actions section
{}
EOF
}

if command -v lms >/dev/null 2>&1; then
    LMS_CMD="lms"
elif [[ -x "$HOME/.lmstudio/bin/lms" ]]; then
    LMS_CMD="$HOME/.lmstudio/bin/lms"
else
    write_empty_menu
    exit 0
fi

lms_stderr="$(mktemp "$CACHE_DIR/lms-ls.XXXXXX")"
cleanup() {
    rm -f "$lms_stderr"
}
trap cleanup EXIT

lms_output=""
if ! lms_output="$("$LMS_CMD" ls 2>"$lms_stderr")"; then
    error_summary=""
    IFS= read -r error_summary <"$lms_stderr" || true
    [[ -n "$error_summary" ]] || error_summary="LM Studio did not return a model list."
    printf 'Error: failed to list LM Studio models: %s\n' "$error_summary" >&2
    exit 1
fi

if [[ -s "$lms_stderr" ]]; then
    while IFS= read -r line; do
        [[ -n "$line" ]] && printf 'Warning: lms ls: %s\n' "$line" >&2
    done <"$lms_stderr"
fi

# Keep up to 20 LLM identifiers. The character restriction makes every value
# safe as both XML text and a quoted shell argument in the generated JSON.
MODELS="$(awk '
    /^LLM/,/^$/ {
        if (NF > 0 && $1 != "LLM" && $1 != "PARAMS") {
            if ($1 ~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) {
                if (accepted < 20) {
                    print $1
                    accepted++
                }
            } else {
                print "Warning: skipping unsafe LM Studio model identifier: " $1 > "/dev/stderr"
            }
        }
    }
' <<<"$lms_output")"

if [[ -z "$MODELS" ]]; then
    write_empty_menu
    exit 0
fi

{
    printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
    printf '%s\n' '<interface>'
    printf '%s\n' '  <object class="GtkMenu" id="menu">'

    first=true
    while IFS= read -r model; do
        [[ -n "$model" ]] || continue
        model_id="${model//\//-}"

        if [[ "$first" == false ]]; then
            printf '%s\n' '    <child>'
            printf '      <object class="GtkSeparatorMenuItem" id="separator_%s"/>\n' "$model_id"
            printf '%s\n' '    </child>'
        fi
        first=false

        printf '%s\n' '    <child>'
        printf '      <object class="GtkMenuItem" id="%s">\n' "$model_id"
        printf '        <property name="label">%s</property>\n' "$model"
        printf '%s\n' '      </object>'
        printf '%s\n' '    </child>'
    done <<<"$MODELS"

    printf '%s\n' '  </object>'
    printf '%s\n' '</interface>'
} >"$MENU_FILE"

{
    printf '%s\n' '// Auto-generated menu actions for LM Studio models'
    printf '%s\n' '// This file should be included in waybar config.jsonc menu-actions section'
    printf '%s\n' '{'

    first=true
    while IFS= read -r model; do
        [[ -n "$model" ]] || continue
        model_id="${model//\//-}"
        action="\$HOME/.config/waybar/scripts/lmstudio_change_model.sh \\\"$model\\\""
        [[ "$first" == true ]] || printf '%s\n' ','
        first=false
        printf '            "%s": "%s"' "$model_id" "$action"
    done <<<"$MODELS"

    printf '\n%s\n' '}'
} >"$CONFIG_SNIPPET_FILE"
