#!/usr/bin/env bash

TMP_FILE="$XDG_RUNTIME_DIR/hyprland-show-desktop"

CURRENT_WORKSPACE=$(hyprctl monitors -j | jq -r '.[] | .activeWorkspace | .name' | head -n1)

if [ -s "$TMP_FILE-$CURRENT_WORKSPACE" ]; then
  # Restore windows
  CMDS=""
  readarray -t ADDRESS_ARRAY < <(grep -v '^$' "$TMP_FILE-$CURRENT_WORKSPACE")

  for address in "${ADDRESS_ARRAY[@]}"
  do
    address=$(echo "$address" | tr -d '[:space:]')
    if [[ -n "$address" ]]; then
      CMDS+="dispatch movetoworkspacesilent name:$CURRENT_WORKSPACE,address:$address;"
    fi
  done

  if [[ -n "$CMDS" ]]; then
    hyprctl --batch "$CMDS"
  fi

  rm "$TMP_FILE-$CURRENT_WORKSPACE"
else
  # Hide windows
  CMDS=""
  TMP_ADDRESS=""
  
  # Get windows from current workspace, excluding special workspaces
  HIDDEN_WINDOWS=$(hyprctl clients -j | jq -r --arg CW "$CURRENT_WORKSPACE" '.[] | select(.workspace.name == $CW and (.workspace.name | startswith("special:") | not)) | .address')

  if [[ -z "$HIDDEN_WINDOWS" ]]; then
    exit 0
  fi

  while IFS= read -r address; do
    address=$(echo "$address" | tr -d '[:space:]')
    if [[ -n "$address" ]]; then
      TMP_ADDRESS+="$address"$'\n'
      CMDS+="dispatch movetoworkspacesilent special:desktop,address:$address;"
    fi
  done <<< "$HIDDEN_WINDOWS"

  if [[ -n "$CMDS" ]]; then
    hyprctl --batch "$CMDS"
    echo -n "$TMP_ADDRESS" | sed -e '/^$/d' > "$TMP_FILE-$CURRENT_WORKSPACE"
  fi
fi
