#!/usr/bin/env bash

# If not running inside kitty, re-exec in kitty (without --hold)
if [ -z "$KITTY_WINDOW_ID" ]; then
    exec kitty --title Notes bash "$0" "$@"
fi

notes_dir="/mnt/SSD_NVME_4TB/Onedrive/Dokumente/0_Notes"

# Ask if the user wants to create a new file
read -rp "Do you want to create a new file? (Y/n) " choice

if [[ "$choice" =~ ^[Yy]$|^$ ]]; then
    # New File
    read -rp "Name your new note file: " new_file
    base_name="${new_file##*/}"
    if [[ "$base_name" != *.* ]]; then
        new_file="${new_file}.txt"
    fi
    touch "$notes_dir/$new_file"
    nvim "$notes_dir/$new_file"
else
    # List existing notes (filenames only)
    echo "Available notes:"
    mapfile -t files < <(basename -a "$notes_dir"/*)
    select fname in "${files[@]}"; do
        if [[ -n "$fname" ]]; then
            nvim "$notes_dir/$fname"
            break
        else
            echo "Invalid selection."
        fi
    done
fi