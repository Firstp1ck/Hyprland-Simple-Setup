#!/usr/bin/env bash

action="$1"

case "$action" in
  shutdown)
    notify-send "Shutdown" "System will power off in 3 seconds..."
    sleep 3
    if ! systemctl poweroff; then
      notify-send "Shutdown" "Failed to shutdown" --urgency=critical
    fi
    ;;
  reboot)
    notify-send "Reboot" "System will reboot in 3 seconds..."
    sleep 3
    if ! systemctl reboot; then
      notify-send "Reboot" "Failed to reboot" --urgency=critical
    fi
    ;;
  suspend)
    notify-send "Suspend" "Suspending system in 3 seconds..."
    sleep 3
    if ! systemctl suspend; then
      notify-send "Suspend" "Failed to suspend" --urgency=critical
    fi
    ;;
  hibernate)
    notify-send "Hibernate" "Hibernating system in 3 seconds..."
    sleep 3
    if ! systemctl hibernate; then
      notify-send "Hibernate" "Failed to hibernate" --urgency=critical
    fi
    ;;
  logout)
    notify-send "Logout" "Logging out in 3 seconds..."
    sleep 3
    if ! hyprctl dispatch exit; then
      notify-send "Logout" "Failed to logout" --urgency=critical
    fi
    ;;
  lock)
    notify-send "Lock Screen" "Locking screen in 3 seconds..."
    sleep 3
    if ! hyprlock; then
      notify-send "Lock Screen" "Failed to lock screen" --urgency=critical
    fi
    ;;
  *)
    notify-send "Power Menu" "Unknown action: $action" --urgency=critical
    ;;
esac