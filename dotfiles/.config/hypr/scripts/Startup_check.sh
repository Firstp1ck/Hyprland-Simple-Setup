#!/bin/bash

sleep 5 # Wait for 5 seconds to allow processes to start

# Function to check if a process is running
check_process() {
    # Check if process is installed otherwise skip
    if ! command -v "$1" &>/dev/null; then
        return 0
    fi
    
    # Check if the process is running
    local process_name="$1"
    if ! pgrep -f "$process_name" >/dev/null; then
        notify-send -u critical "Autostart Warning" "Process '$process_name' is not running!"
        return 1
    fi
    return 0
}

check_dolphin_fix() {
    if [ ! -f "/tmp/dolphin-fix-ran" ]; then
        notify-send -u critical "Autostart Warning" "Dolphin fix script did not run!"
        return 1
    fi
    return 0
}

check_wallpaper_change() {
    if [ ! -f "/tmp/wallpaper-change-ran" ]; then
        notify-send -u critical "Autostart Warning" "Wallpaper change script did not run!"
        return 1
    fi
    return 0
}

check_numlock_setting() {
    if [ ! -f "/tmp/numlock-set" ]; then
        notify-send -u critical "Autostart Warning" "Numlock setting was not applied!"
        return 1
    fi
    return 0
}

# Array of processes to check (extracted from autostart.conf)
processes=(
    "polkitd"
    "nm-applet"
    "hyprpaper"
    "pypr"
    "wl-clip-persist"
    "wl-clipboard-history"
    "dunst"
    "hypridle"
    "xwaylandvideobridge"
    "waybar"
    "hyprsunset"
    "kitty"
)

# Counter for failed processes
failed=0

# Add numlock check before other checks
if ! check_numlock_setting; then
    ((failed++))
fi
# Check for dolphin fix
if ! check_dolphin_fix; then
    ((failed++))
fi

# Check for wallpaper change
if ! check_wallpaper_change; then
    ((failed++))
fi

# Check each process
for process in "${processes[@]}"; do
    if ! check_process "$process"; then
        ((failed++))
    fi
done

# Final summary notification if any process failed
if [ $failed -gt 0 ]; then
    notify-send -u critical "Autostart Status" "$failed processes failed to start!"
else
    notify-send -u normal "Autostart Status" "All processes are running!"
fi

# Clearing all temp files
rm -f /tmp/dolphin-fix-ran
rm -f /tmp/wallpaper-change-ran
rm -f /tmp/numlock-set