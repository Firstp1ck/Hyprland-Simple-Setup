#!/bin/bash

# Get notification count from history
COUNT=$(dunstctl history | jq '.data[0] | length')
HISTORY_JSON=$(dunstctl history)

# Extract latest messages (max 5) for tooltip
MESSAGES=$(echo "$HISTORY_JSON" | jq -r '.data[0][].message.data' | head -n 40 | sed -e 's/<[^>]*>//g' -e 's/&apos;/'"'"'/g' -e 's/&lt;/</g' -e 's/&gt;/>/g')

# Notification icon
ICON="󰂚"

# Escape newlines and double quotes for JSON
ESCAPED_MESSAGES=$(echo "$MESSAGES" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')

if [ "$COUNT" -gt 0 ] && [ -n "$MESSAGES" ]; then
    TOOLTIP="In history: $COUNT\\n$ESCAPED_MESSAGES"
    echo "{\"text\": \"$ICON $COUNT\", \"tooltip\": \"$TOOLTIP\"}"
else
    echo "{\"text\": \"$ICON\", \"tooltip\": \"No notifications in history\"}"
fi