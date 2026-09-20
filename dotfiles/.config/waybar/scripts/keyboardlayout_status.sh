#!/usr/bin/env bash

current_im_name=$(fcitx5-remote -n)

if [ "$current_im_name" = "mozc" ]; then
    echo "Jap 🇯🇵"
elif [ "$current_im_name" = "keyboard-ch" ]; then
    echo "CH 🇨🇭"
else
    echo "N/A"
fi