#!/usr/bin/env bash
set -euo pipefail

roles_file=${HSS_ROLES_FILE:-$HOME/.config/hypr/roles.json}
if [[ -z "${INSIDE_HSS_NOTES:-}" ]]; then
  exec env INSIDE_HSS_NOTES=1 "$HOME/.config/hypr/scripts/term_exec.sh" \
    --app-id hss-notes --title Notes -- bash "$0" "$@"
fi

editor=$(jq -er '.roles.tui_editor.editor_bin' "$roles_file")
notes_dir=${HSS_NOTES_DIR:-$HOME/Dokumente/0_Notes}
mkdir -p "$notes_dir"

read -rp "Do you want to create a new file? (Y/n) " choice
if [[ "$choice" =~ ^[Yy]$|^$ ]]; then
  read -rp "Name your new note file: " new_file
  base_name=${new_file##*/}
  [[ "$base_name" == *.* ]] || new_file=${new_file}.txt
  touch "$notes_dir/$new_file"
  exec "$editor" "$notes_dir/$new_file"
fi

printf 'Available notes:\n'
shopt -s nullglob
files=("$notes_dir"/*)
((${#files[@]} > 0)) || { printf 'No notes found.\n'; exit 0; }
select file in "${files[@]}"; do
  [[ -n "$file" ]] || { printf 'Invalid selection.\n'; continue; }
  exec "$editor" "$file"
done
