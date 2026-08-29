#!/usr/bin/env bash
# Report WireGuard VPN status as one-line Waybar JSON.

set -u

readonly IFACE="wg-proton"
vpn_up=false

if command -v nmcli >/dev/null 2>&1 && nmcli connection show "$IFACE" >/dev/null 2>&1; then
    nm_state="$(nmcli -g GENERAL.STATE connection show "$IFACE" 2>/dev/null | head -n1 || true)"
    if [[ "$nm_state" == *activated* ]]; then
        vpn_up=true
    fi
fi

if [[ "$vpn_up" == false ]] && ip addr show dev "$IFACE" 2>/dev/null | grep -q 'inet '; then
    vpn_up=true
fi

if [[ "$vpn_up" == false ]] && ip route show dev "$IFACE" 2>/dev/null | grep -q .; then
    vpn_up=true
fi

if [[ "$vpn_up" == true ]]; then
    ip_address="$(ip -o -4 addr show dev "$IFACE" 2>/dev/null | awk 'NR == 1 { split($4, address, "/"); print address[1] }')"
    tooltip="VPN: $IFACE (UP)"
    if [[ -n "$ip_address" ]]; then
        tooltip+=$'\n'"IP: $ip_address"
    fi
    tooltip+=$'\n'"Left click: disconnect • Right click: show status"
    css_class="vpn-up"
else
    tooltip="VPN: $IFACE (DOWN)"$'\n'"Left click: connect • Right click: show status"
    css_class="vpn-down"
fi

jq -cn \
    --arg text "󰖂" \
    --arg tooltip "$tooltip" \
    --arg class "$css_class" \
    '{text: $text, tooltip: $tooltip, class: $class}'
