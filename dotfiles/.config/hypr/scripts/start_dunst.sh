#!/bin/bash

# Clear the log file if it exists
true > /tmp/dunst.log

# Try to start dunst three times
for i in {1..3}; do
    echo "Attempt $i to start dunst..." >> /tmp/dunst.log
    systemctl --user start dunst.service >> /tmp/dunst.log 2>&1
    
    # Check if dunst is running
    if systemctl --user is-active --quiet dunst.service; then
        echo "Dunst started successfully on attempt $i" >> /tmp/dunst.log
        break
    else
        echo "Failed to start dunst on attempt $i" >> /tmp/dunst.log
    fi
    
    # Wait a bit before next attempt
    sleep 1
done

# Log the final status
echo "Final dunst status:" >> /tmp/dunst.log
systemctl --user status dunst.service >> /tmp/dunst.log 2>&1
