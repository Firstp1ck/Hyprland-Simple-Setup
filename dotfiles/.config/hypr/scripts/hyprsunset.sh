#!/bin/sh

# Kill existing process to prevent duplicates
pkill -x hyprsunset

# Check current screen shader state
if hyprctl getoption decoration:screen_shader | grep -q "\./hyprsunset"; then
    # Switch to 6000K (daylight)
    hyprsunset -t 6000 &
    notify-send "Daylight Mode (6000K)"
else
    # Switch to 4000K (warm)
    hyprsunset -t 4000 &
    notify-send "Warm Mode (4000K)"
fi
#!/bin/bash
current_temp=$(hyprctl hyprsunset | grep 'Temperature:' | awk '{print $2}')

if [ "$current_temp" -ge 6500 ]; then
    hyprctl hyprsunset temperature 4000
else
    hyprctl hyprsunset temperature 6500
fi
