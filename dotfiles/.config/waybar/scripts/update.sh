#!/bin/bash

# 1. Update Arch mirrorlist with fastest mirrors from CH, AT, DE
notify-send "Update" "Updating mirrorlist with reflector..."
sudo reflector --country Switzerland,Austria,Germany \
  --protocol https \
  --latest 10 \
  --sort rate \
  --save /etc/pacman.d/mirrorlist

# 2. Update system packages
notify-send "Update" "Updating system packages with pacman..."
sudo pacman -Syu --noconfirm

# 3. Update AUR packages with yay
notify-send "Update" "Updating AUR packages with yay..."
yay -Syu --noconfirm

notify-send "Update" "System and AUR packages are up to date."
