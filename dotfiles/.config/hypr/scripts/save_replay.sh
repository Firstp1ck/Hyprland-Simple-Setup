#!/usr/bin/env bash

replay_dir="/mnt/SSD_NVME_4TB/Replays"

# Create replay directory if it doesn't exist
mkdir -p "$replay_dir"

# Store gpu-screen-recorder command with original formatting
GSR_CMD="gpu-screen-recorder \
    -w DP-1 \
    -s 2560x1440 \
    -f 60 \
    -c mkv \
    -r 60 \
    -a alsa_output.usb-046d_G435_Wireless_Gaming_Headset_V001008005.1-01.analog-stereo.monitor \
    -restart-replay-on-save yes \
    -o \"$replay_dir\""

if ! pgrep -fa gpu-screen-recorder | grep -q "$replay_dir"; then
    dunstify "GPU Screen Recorder" "Starting replay buffer..."
    eval "$GSR_CMD &> /tmp/gpu-screen-recorder.log &"
    
    sleep 2
    if ! pgrep -fa gpu-screen-recorder | grep -q "$replay_dir"; then
        # Try starting again
        eval "$GSR_CMD &> /tmp/gpu-screen-recorder.log &"
        
        sleep 2
        if ! pgrep -fa gpu-screen-recorder | grep -q "$replay_dir"; then
            dunstify "GPU Screen Recorder" "Failed to start replay buffer"
            exit 1
        fi
    fi
    exit 0
fi

# Try to save the replay
pkill -f -SIGUSR1 gpu-screen-recorder
sleep 1

if ! pgrep -fa gpu-screen-recorder > /dev/null; then
    # Try one more time
    pkill -f -SIGUSR1 gpu-screen-recorder
    sleep 1
    if ! pgrep -fa gpu-screen-recorder > /dev/null; then
        dunstify "GPU Screen Recorder" "Failed to save replay buffer - recorder not responding"
        exit 1
    fi
fi

touch /tmp/save-replay
dunstify "GPU Screen Recorder" "Saving replay buffer..."