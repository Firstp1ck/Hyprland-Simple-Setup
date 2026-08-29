#!/usr/bin/env bash
set -euo pipefail

IFACE="wg-proton"
CONFIG_FILE="/etc/wireguard/${IFACE}.conf"

# Check if we're already running as root
if [ "$EUID" -eq 0 ]; then
    SUDO_CMD=""
else
    SUDO_CMD="sudo"
fi

# IPv6 leak protection - disable IPv6 when VPN is active to prevent leaks
disable_ipv6() {
  echo "Disabling IPv6 to prevent leaks..." >&2
  $SUDO_CMD sysctl -q -w net.ipv6.conf.all.disable_ipv6=1 2>/dev/null || true
}

enable_ipv6() {
  echo "Re-enabling IPv6..." >&2
  $SUDO_CMD sysctl -q -w net.ipv6.conf.all.disable_ipv6=0 2>/dev/null || true
}

# Check if required commands exist
check_commands() {
  local missing_commands=()
  
  if ! command -v ip &>/dev/null; then
    missing_commands+=("ip")
  fi
  
  if [ ${#missing_commands[@]} -gt 0 ]; then
    echo "Error: Missing required commands: ${missing_commands[*]}" >&2
    exit 1
  fi
}

# Detect if VPN is managed by NetworkManager
is_networkmanager_managed() {
  if ! command -v nmcli &>/dev/null; then
    return 1
  fi
  
  # Check if connection exists in NetworkManager (even if inactive)
  if nmcli connection show "$IFACE" &>/dev/null 2>&1; then
    return 0
  fi
  
  # Also check if any connection uses this interface name
  # Temporarily disable set -e for this check
  set +e
  nmcli -t connection show 2>/dev/null | grep -q "^$IFACE:" 2>/dev/null
  local grep_result=$?
  set -e
  
  if [ $grep_result -eq 0 ]; then
    return 0
  fi
  
  # Check if interface is managed by NetworkManager (even if connection profile doesn't exist)
  set +e
  nmcli device status 2>/dev/null | grep -q "^$IFACE" 2>/dev/null
  grep_result=$?
  set -e
  
  if [ $grep_result -eq 0 ]; then
    return 0
  fi
  
  return 1
}

# Sync NetworkManager connection with config file
# Returns 0 if NM connection is in sync (or was successfully synced)
# Returns 1 if sync failed or NM is not available
sync_networkmanager_config() {
  if ! command -v nmcli &>/dev/null; then
    return 1
  fi
  
  # Check if config file exists
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "Warning: Config file $CONFIG_FILE not found, cannot sync" >&2
    return 1
  fi
  
  # Extract peer public key from config file
  local config_peer_key
  config_peer_key=$($SUDO_CMD grep "^PublicKey" "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d ' ')
  
  if [ -z "$config_peer_key" ]; then
    echo "Warning: Could not extract peer public key from config file" >&2
    return 1
  fi
  
  # Check if NetworkManager connection exists
  if ! nmcli connection show "$IFACE" &>/dev/null 2>&1; then
    # Connection doesn't exist, import it
    echo "NetworkManager connection '$IFACE' not found, importing from config..." >&2
    if $SUDO_CMD nmcli connection import type wireguard file "$CONFIG_FILE" 2>/dev/null; then
      echo "Successfully imported WireGuard config into NetworkManager" >&2
      return 0
    else
      echo "Warning: Failed to import config into NetworkManager" >&2
      return 1
    fi
  fi
  
  # Get peer public key from NetworkManager connection file
  # The peer key is stored as a section header: [wireguard-peer.KEY]
  local nm_peer_key
  local nm_conn_file="/etc/NetworkManager/system-connections/${IFACE}.nmconnection"
  if [ -f "$nm_conn_file" ]; then
    # Extract peer key from section header [wireguard-peer.KEY]
    nm_peer_key=$($SUDO_CMD grep "^\[wireguard-peer\." "$nm_conn_file" 2>/dev/null | head -1 | sed 's/\[wireguard-peer\.//' | sed 's/\]$//')
  fi
  
  # Compare keys
  if [ "$config_peer_key" != "$nm_peer_key" ]; then
    echo "NetworkManager connection is out of sync with config file" >&2
    echo "  Config peer key: $config_peer_key" >&2
    echo "  NM peer key:     $nm_peer_key" >&2
    echo "Re-importing config into NetworkManager..." >&2
    
    # Delete old connection and re-import
    $SUDO_CMD nmcli connection delete "$IFACE" 2>/dev/null || true
    
    if $SUDO_CMD nmcli connection import type wireguard file "$CONFIG_FILE" 2>/dev/null; then
      echo "Successfully re-imported WireGuard config into NetworkManager" >&2
      return 0
    else
      echo "Warning: Failed to re-import config into NetworkManager" >&2
      return 1
    fi
  fi
  
  # Keys match, connection is in sync
  return 0
}

# Check if WireGuard config file exists (only needed for wg-quick)
check_config() {
  local cmd_to_check="${1:-}"
  
  # If managed by NetworkManager, we don't need the config file
  if is_networkmanager_managed; then
    return 0
  fi
  
  # If interface already exists and is up, we don't need the config file
  if is_up && ip link show dev "$IFACE" 2>/dev/null | grep -qE "<.*UP.*>"; then
    return 0
  fi
  
  # If NetworkManager is available, prefer it over wg-quick
  # NetworkManager can handle WireGuard interfaces even without explicit connection profiles
  if command -v nmcli &>/dev/null; then
    # For commands that modify the VPN, try NetworkManager first
    case "$cmd_to_check" in
      on|off|toggle)
        # NetworkManager might be able to handle it
        return 0
        ;;
      status)
        # For status, we can check without config file
        return 0
        ;;
    esac
  fi
  
  # Otherwise, we need the config file for wg-quick
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: WireGuard config file not found: $CONFIG_FILE" >&2
    echo "Note: If this VPN is managed by NetworkManager, this check can be skipped." >&2
    exit 1
  fi
}

# Check if WireGuard kernel module is loaded
check_wireguard_module() {
  # Check if module is loaded (check first column of lsmod output)
  if ! lsmod | awk '$1 == "wireguard" {found=1} END {exit !found}'; then
    echo "Warning: WireGuard kernel module may not be loaded" >&2
  fi
}

# Get default gateway interface
get_default_gateway() {
  ip route show default | awk '/default/ {print $5}' | head -n1
}

# Check if default route exists
check_default_route() {
  # Check if there's actually a default route (not just if the command succeeds)
  local route
  route=$(ip route show default 2>/dev/null | grep -v "$IFACE" | head -1)
  if [ -z "$route" ]; then
    return 1
  fi
  return 0
}

# Restore default route if missing
restore_default_route() {
  echo "Checking for network interfaces..." >&2
  
  # Find active network interfaces (excluding VPN, loopback, docker, virbr, etc.)
  local ifaces
  ifaces=$(ip -o link show up 2>/dev/null | awk -F': ' '{print $2}' | grep -vE "^(lo|$IFACE|docker|virbr|br-|veth)" | head -5)
  
  for iface in $ifaces; do
    echo "Checking interface: $iface" >&2
    
    # Check if this interface has a gateway configured
    local gateway
    gateway=$(ip route show dev "$iface" 2>/dev/null | awk '/via/ {print $3; exit}')
    
    if [ -n "$gateway" ]; then
      echo "Found gateway $gateway on $iface, adding default route..." >&2
      $SUDO_CMD ip route add default via "$gateway" dev "$iface" 2>/dev/null || true
      
      # Check if route was added
      if check_default_route; then
        echo "Default route restored via $iface" >&2
        return 0
      fi
    fi
  done
  
  echo "Could not automatically restore default route" >&2
  return 1
}

# Check DNS configuration
check_dns() {
  if [ -f /etc/resolv.conf ]; then
    if ! grep -qE "^nameserver" /etc/resolv.conf; then
      echo "Warning: No nameservers found in /etc/resolv.conf" >&2
      return 1
    fi
  else
    echo "Warning: /etc/resolv.conf not found" >&2
    return 1
  fi
  return 0
}

# Diagnose connectivity issues
diagnose_connectivity() {
  echo "=== Connectivity Diagnosis ===" >&2
  
  # Check default route
  if ! check_default_route; then
    echo "ERROR: No default route found!" >&2
    echo "Current routes:" >&2
    ip route show | head -10 >&2
    return 1
  else
    echo "✓ Default route exists" >&2
    ip route show default >&2
  fi
  
  # Check DNS
  if ! check_dns; then
    echo "WARNING: DNS configuration may be broken" >&2
  else
    echo "✓ DNS configuration looks OK" >&2
  fi
  
  # Check if we can reach a gateway
  local gateway
  gateway=$(ip route show default | awk '{print $3}' | head -n1)
  if [ -n "$gateway" ]; then
    if ping -c 1 -W 1 "$gateway" &>/dev/null; then
      echo "✓ Can ping gateway: $gateway" >&2
    else
      echo "WARNING: Cannot ping gateway: $gateway" >&2
    fi
  fi
  
  return 0
}

is_up() {
  # Check if interface exists, is UP, and has an IP address (indicating active connection)
  if ! ip link show dev "$IFACE" &>/dev/null; then
    return 1
  fi
  
  # Check if interface has UP flag
  if ! ip link show dev "$IFACE" 2>/dev/null | grep -qE "<.*UP.*>"; then
    return 1
  fi
  
  # Check if interface has an IP address (more reliable indicator of active VPN)
  if ! ip addr show dev "$IFACE" 2>/dev/null | grep -q "inet "; then
    return 1
  fi
  
  return 0
}

# Run checks
check_commands
check_wireguard_module

cmd="${1:-toggle}"

# Only check config for commands that need it
case "$cmd" in
  on|off|toggle|status)
    check_config "$cmd"
    ;;
esac

case "$cmd" in
  on)
    if is_up; then
      echo "Warning: $IFACE is already up" >&2
      exit 0
    fi
    
    # Always try NetworkManager first if available (preferred method)
    if command -v nmcli &>/dev/null; then
      # Ensure NetworkManager connection is in sync with config file
      sync_networkmanager_config
      
      # Try to bring up via NetworkManager connection
      if nmcli connection up "$IFACE" 2>/dev/null; then
        # Success
        disable_ipv6
        exit 0
      fi
      # If connection doesn't exist, try to connect the device directly
      if nmcli device connect "$IFACE" 2>/dev/null; then
        # Success
        disable_ipv6
        exit 0
      fi
      # If both fail, NetworkManager might not have the connection configured
      # Fall through to wg-quick
    fi
    
    # Fallback to wg-quick if NetworkManager is not available or failed
    # Try to bring up with wg-quick
    # Check if sudo is available and can be used
    if ! sudo -n true 2>/dev/null; then
      echo "Error: sudo password required. Please use the wrapper script (vpn_toggle_wrapper.sh) or run with sudo." >&2
      exit 1
    fi
    
    echo "Attempting to bring up $IFACE using wg-quick..." >&2
    
    # Fix resolvconf signature mismatch before starting VPN
    if command -v resolvconf &>/dev/null; then
      echo "Updating resolvconf to fix potential signature mismatch..." >&2
      $SUDO_CMD resolvconf -u 2>/dev/null || true
    fi
    
    # Disable set -e temporarily to capture exit code
    set +e
    OUTPUT=$($SUDO_CMD wg-quick up "$IFACE" 2>&1)
    EXIT_CODE=$?
    set -e
    
    echo "wg-quick exit code: $EXIT_CODE" >&2
    
    # Check if it's just a resolvconf issue (interface might still be up)
    if [ $EXIT_CODE -ne 0 ]; then
      sleep 1
      # Check if interface exists and is up (use set +e to prevent exit on failure)
      set +e
      INTERFACE_EXISTS=$(ip link show dev "$IFACE" 2>/dev/null && echo "yes" || echo "no")
      if [ "$INTERFACE_EXISTS" = "yes" ]; then
        INTERFACE_UP=$(ip link show dev "$IFACE" 2>/dev/null | grep -qE "<.*UP.*>" && echo "yes" || echo "no")
      else
        INTERFACE_UP="no"
      fi
      set -e
      
      if [ "$INTERFACE_UP" = "yes" ]; then
        # Interface is up despite error - likely just DNS/resolvconf issue
        echo "Warning: VPN interface is up, but DNS configuration had issues" >&2
        if echo "$OUTPUT" | grep -q "resolvconf"; then
          # Try to fix resolvconf
          if command -v resolvconf &>/dev/null; then
            echo "Attempting to fix resolvconf..." >&2
            $SUDO_CMD resolvconf -u 2>/dev/null || true
          fi
        fi
        echo "VPN is now UP" >&2
        disable_ipv6
        # Consider it a success if the interface is up
      else
        echo "Error: Failed to bring up $IFACE" >&2
        echo "wg-quick output:" >&2
        echo "$OUTPUT" >&2
        echo "" >&2
        echo "Note: If using NetworkManager, ensure the connection is configured." >&2
        exit 1
      fi
    else
      echo "Successfully brought up $IFACE" >&2
      disable_ipv6
    fi
    ;;
  off)
    if ! is_up; then
      echo "Warning: $IFACE is already down" >&2
      exit 0
    fi
    
    # Try NetworkManager first if available
    if command -v nmcli &>/dev/null; then
      if nmcli connection down "$IFACE" 2>/dev/null || nmcli device disconnect "$IFACE" 2>/dev/null; then
        # Success with NetworkManager
        :
      else
          # NetworkManager failed, try wg-quick
          if [ -n "$SUDO_CMD" ] && ! $SUDO_CMD -n true 2>/dev/null; then
            echo "Error: sudo password required. Please use the wrapper script (vpn_toggle_wrapper.sh) or run with sudo." >&2
            exit 1
          fi
        if ! $SUDO_CMD wg-quick down "$IFACE"; then
          echo "Error: Failed to bring down $IFACE" >&2
          exit 1
        fi
      fi
    else
      # No NetworkManager, use wg-quick
      if ! sudo -n true 2>/dev/null; then
        echo "Error: sudo password required. Please use the wrapper script (vpn_toggle_wrapper.sh) or run with sudo." >&2
        exit 1
      fi
      if ! $SUDO_CMD wg-quick down "$IFACE"; then
        echo "Error: Failed to bring down $IFACE" >&2
        exit 1
      fi
    fi
    
    # Restore routing after disconnect
    sleep 1
    if ! check_default_route; then
      echo "Warning: Default route missing after disconnect, attempting to restore..." >&2
      restore_default_route
      sleep 1
      if ! check_default_route; then
        echo "Warning: Could not restore default route automatically." >&2
        echo "Trying to restart NetworkManager..." >&2
        if $SUDO_CMD systemctl restart NetworkManager 2>/dev/null; then
          echo "NetworkManager restarted" >&2
          sleep 3
        fi
      fi
    fi
    enable_ipv6
    echo "VPN disconnected" >&2
    ;;
  toggle)
    if is_up; then
      # Try NetworkManager first if available
      if command -v nmcli &>/dev/null; then
        if nmcli connection down "$IFACE" 2>/dev/null || nmcli device disconnect "$IFACE" 2>/dev/null; then
          # Success with NetworkManager
          :
        else
          # NetworkManager failed, try wg-quick
          if [ -n "$SUDO_CMD" ] && ! $SUDO_CMD -n true 2>/dev/null; then
            echo "Error: sudo password required. Please use the wrapper script (vpn_toggle_wrapper.sh) or run with sudo." >&2
            exit 1
          fi
        if ! $SUDO_CMD wg-quick down "$IFACE"; then
          echo "Error: Failed to bring down $IFACE" >&2
          exit 1
        fi
        fi
      else
      # No NetworkManager, use wg-quick
      if ! sudo -n true 2>/dev/null; then
        echo "Error: sudo password required. Please use the wrapper script (vpn_toggle_wrapper.sh) or run with sudo." >&2
        exit 1
      fi
      if ! $SUDO_CMD wg-quick down "$IFACE"; then
        echo "Error: Failed to bring down $IFACE" >&2
        exit 1
      fi
      fi
      # Restore routing after disconnect
      sleep 1
      if ! check_default_route; then
        echo "Warning: Default route missing after disconnect, attempting to restore..." >&2
        restore_default_route
        sleep 1
        if ! check_default_route; then
          echo "Warning: Could not restore default route automatically." >&2
          echo "Trying to restart NetworkManager..." >&2
          if $SUDO_CMD systemctl restart NetworkManager 2>/dev/null; then
            echo "NetworkManager restarted" >&2
            sleep 3
          fi
        fi
      fi
      enable_ipv6
      echo "VPN disconnected" >&2
    else
      # Always try NetworkManager first if available (preferred method)
      if command -v nmcli &>/dev/null; then
        # Ensure NetworkManager connection is in sync with config file
        sync_networkmanager_config
        
        # Try to bring up via NetworkManager connection
        if nmcli connection up "$IFACE" 2>/dev/null; then
          # Success
          disable_ipv6
          exit 0
        fi
        # If connection doesn't exist, try to connect the device directly
        if nmcli device connect "$IFACE" 2>/dev/null; then
          # Success
          disable_ipv6
          exit 0
        fi
        # If both fail, NetworkManager might not have the connection configured
        # Fall through to wg-quick
      fi
      
      # Fallback to wg-quick if NetworkManager is not available or failed
      # Try to bring up with wg-quick
      # Check if we need sudo and if it's available
      if [ -n "$SUDO_CMD" ] && ! $SUDO_CMD -n true 2>/dev/null; then
        echo "Error: sudo password required. Please use the wrapper script (vpn_toggle_wrapper.sh) or run with sudo." >&2
        exit 1
      fi
      
      echo "Attempting to bring up $IFACE using wg-quick..." >&2
      
      # Create a temporary config without DNS to avoid resolvconf issues
      # NetworkManager already handles DNS, so we don't need wg-quick to do it
      CONFIG_FILE="/etc/wireguard/${IFACE}.conf"
      TEMP_CONFIG=""
      
      if [ -f "$CONFIG_FILE" ] && grep -q "^DNS" "$CONFIG_FILE"; then
        echo "Creating temporary config without DNS to avoid resolvconf conflicts..." >&2
        TEMP_CONFIG=$(mktemp)
        # Copy config but remove DNS lines
        $SUDO_CMD grep -v "^DNS" "$CONFIG_FILE" > "$TEMP_CONFIG" 2>/dev/null || {
          # If that fails, try with cat and grep
          $SUDO_CMD cat "$CONFIG_FILE" | grep -v "^DNS" > "$TEMP_CONFIG"
        }
        $SUDO_CMD chmod 600 "$TEMP_CONFIG"
        
        # Bring up using the temp config
        set +e
        OUTPUT=$($SUDO_CMD wg-quick up "$TEMP_CONFIG" 2>&1)
        EXIT_CODE=$?
        set -e
        
        # Rename the interface if needed (wg-quick uses filename as interface name)
        TEMP_IFACE=$(basename "$TEMP_CONFIG" .conf)
        if [ "$EXIT_CODE" -eq 0 ] && [ "$TEMP_IFACE" != "$IFACE" ]; then
          # Interface was created with wrong name, need to rename
          # Actually wg-quick uses full path, so interface name will be the temp file name
          # Let's just use the original config but suppress the resolvconf error
          $SUDO_CMD wg-quick down "$TEMP_CONFIG" 2>/dev/null || true
          
          # Try original config with resolvconf fix
          if command -v resolvconf &>/dev/null; then
            $SUDO_CMD resolvconf -u 2>/dev/null || true
          fi
          set +e
          OUTPUT=$($SUDO_CMD wg-quick up "$IFACE" 2>&1)
          EXIT_CODE=$?
          set -e
        fi
        
        # Clean up temp file
        rm -f "$TEMP_CONFIG" 2>/dev/null || true
      else
        # No DNS in config or config doesn't exist, just try normally
        if command -v resolvconf &>/dev/null; then
          $SUDO_CMD resolvconf -u 2>/dev/null || true
        fi
        set +e
        OUTPUT=$($SUDO_CMD wg-quick up "$IFACE" 2>&1)
        EXIT_CODE=$?
        set -e
      fi
      
      # Always show output for debugging
      if [ $EXIT_CODE -ne 0 ]; then
        echo "wg-quick exited with code $EXIT_CODE" >&2
      fi
      
      # Check if it's just a resolvconf issue (interface might still be up)
      if [ $EXIT_CODE -ne 0 ]; then
        sleep 1
        # Check if interface exists and is up
        set +e
        INTERFACE_EXISTS=$(ip link show dev "$IFACE" 2>/dev/null && echo "yes" || echo "no")
        if [ "$INTERFACE_EXISTS" = "yes" ]; then
          INTERFACE_UP=$(ip link show dev "$IFACE" 2>/dev/null | grep -qE "<.*UP.*>" && echo "yes" || echo "no")
        else
          INTERFACE_UP="no"
        fi
        set -e
        
        if [ "$INTERFACE_UP" = "yes" ]; then
          # Interface is up despite error - success
          echo "VPN is now UP (DNS handled by NetworkManager)" >&2
          disable_ipv6
        else
          echo "Error: Failed to bring up $IFACE" >&2
          echo "wg-quick output:" >&2
          echo "$OUTPUT" >&2
          echo "" >&2
          echo "Hint: The resolvconf issue can be fixed by removing the DNS line from $CONFIG_FILE" >&2
          echo "      or by importing the VPN into NetworkManager: nmcli connection import type wireguard file $CONFIG_FILE" >&2
          exit 1
        fi
      else
        echo "Successfully brought up $IFACE" >&2
        disable_ipv6
      fi
    fi
    ;;
  status)
    if is_up; then
      echo "$IFACE is UP"
      if is_networkmanager_managed; then
        echo "Managed by: NetworkManager"
        nmcli connection show "$IFACE" 2>/dev/null | grep -E "(GENERAL.STATE|IP4|IP6)" || true
      else
        if ! $SUDO_CMD wg show "$IFACE" 2>/dev/null; then
          echo "Warning: Could not retrieve WireGuard status for $IFACE" >&2
        fi
      fi
    else
      echo "$IFACE is DOWN"
    fi
    ;;
  diagnose)
    diagnose_connectivity
    ;;
  fix)
    echo "Attempting to fix connectivity issues..." >&2
    # Ensure VPN is down
    if is_up; then
      echo "Bringing down $IFACE first..." >&2
      if is_networkmanager_managed; then
        nmcli connection down "$IFACE" || true
      else
        if sudo -n true 2>/dev/null; then
          $SUDO_CMD wg-quick down "$IFACE" || true
        fi
      fi
      sleep 1
    fi
    
    # Restore default route
    if ! check_default_route; then
      echo "Restoring default route..." >&2
      restore_default_route
      sleep 1
    fi
    
    # Run diagnostics
    diagnose_connectivity
    
    if check_default_route && check_dns; then
      echo "Connectivity should be restored. Try pinging a host to verify." >&2
    else
      echo "Some issues remain. You may need to:" >&2
      if is_networkmanager_managed; then
        echo "  1. Restart NetworkManager: sudo systemctl restart NetworkManager" >&2
      fi
      echo "  2. Or restart your network service" >&2
      echo "  3. Or manually configure your default route" >&2
    fi
    ;;
  *)
    echo "Usage: $0 {on|off|toggle|status|diagnose|fix}" >&2
    exit 2
    ;;
esac

