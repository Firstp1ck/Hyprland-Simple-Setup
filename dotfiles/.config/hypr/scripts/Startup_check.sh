#!/usr/bin/env bash
set -u

sleep 10
roles_file=${HSS_ROLES_FILE:-$HOME/.config/hypr/roles.json}

check_process() {
    local process_name=$1
    if ! pgrep -f "(^|/)$process_name([[:space:]]|$)" >/dev/null; then
        notify-send -u critical "Autostart Warning" "Process '$process_name' is not running!"
        return 1
    fi
}

check_marker() {
    local marker=$1 description=$2
    if [[ ! -f $marker ]]; then
        notify-send -u critical "Autostart Warning" "$description"
        return 1
    fi
}

processes=(hyprpaper hypridle wl-clip-persist wl-clipboard-history)
if [[ -r $roles_file ]]; then
    while IFS= read -r process; do
        [[ -z $process ]] || processes+=("$process")
    done < <(jq -r '
        .roles.browser.executable,
        (.roles.gui_editor.executable // empty),
        .roles.notifications.executable,
        .roles.bar.executable,
        (.roles.dock.executable // empty)
    ' "$roles_file")
fi

failed=0
check_marker /tmp/dolphin-fix-ran "Dolphin fix script did not run!" || ((failed++))
check_marker /tmp/wallpaper-change-ran "Wallpaper change did not complete successfully!" || ((failed++))
check_marker /tmp/numlock-set "Numlock setting was not applied!" || ((failed++))
for process in "${processes[@]}"; do
    check_process "$process" || ((failed++))
done

if ((failed > 0)); then
    notify-send -u critical "Autostart Status" "$failed processes failed to start!"
else
    notify-send -u normal "Autostart Status" "All selected autostart processes are running!"
fi

rm -f /tmp/dolphin-fix-ran /tmp/wallpaper-change-ran /tmp/numlock-set /tmp/rsync_success
