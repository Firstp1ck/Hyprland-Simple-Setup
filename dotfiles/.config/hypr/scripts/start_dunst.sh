#!/usr/bin/env bash

MAX_TRIES=3
TRIES=0

while [ $TRIES -lt $MAX_TRIES ]; do
    if ! systemctl --user start dunst || dunst; then
        sleep 1
        if pgrep -x dunst > /dev/null; then
            notify-send "Dunst started successfully"
            exit 0
        fi
    fi
    TRIES=$((TRIES + 1))
    sleep 1
done

echo "Failed to start Dunst after $MAX_TRIES attempts" >> /tmp/dunst_error.log
exit 1