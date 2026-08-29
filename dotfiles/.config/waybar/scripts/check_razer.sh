#!/usr/bin/env bash

# Check for Razer devices
if lsusb | grep -i razer > /dev/null; then
    exit 0  # Device found, return success
else
    exit 1  # Device not found, return failure
fi 