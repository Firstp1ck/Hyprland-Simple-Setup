#!/bin/bash

if bluetoothctl show | grep -q 'Powered: yes'; then
  bluetoothctl power off >/dev/null
  notify-send -e -u low "Bluetooth Disabled" "Bluetooth has been turned off"
else
  bluetoothctl power on >/dev/null
  notify-send -e -u low "Bluetooth Enabled" "Bluetooth has been turned on"
fi