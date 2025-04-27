#!/bin/bash
#
# vpn-monitor.sh - VPN Connection Monitoring Script
#
# This script runs periodically to check if the VPN connection is active.
# If the connection is down, it stops the torrent client for safety and
# attempts to reconnect to a different VPN server.
#
# The script prioritizes US-based servers when available, falling back
# to other servers if necessary.
#

# Source the logging library
source /etc/scripts/logging.sh

# Create a cooldown file path
COOLDOWN_FILE="/tmp/vpn_reconnect_cooldown"

# Check if we're in a cooldown period to prevent rapid reconnections
# Returns 0 if we should proceed, 1 if we're in cooldown
check_cooldown() {
    # If cooldown file exists and is less than 15 minutes old, we're in cooldown
    if [ -f "$COOLDOWN_FILE" ]; then
        COOLDOWN_TIME=$(cat "$COOLDOWN_FILE")
        CURRENT_TIME=$(date +%s)
        ELAPSED_TIME=$((CURRENT_TIME - COOLDOWN_TIME))

        # 15 minute cooldown (900 seconds)
        if [ $ELAPSED_TIME -lt 900 ]; then
            REMAINING=$((900 - ELAPSED_TIME))
            log_info "In reconnection cooldown period. $REMAINING seconds remaining."
            return 1
        else
            log_debug "Cooldown period expired."
            rm -f "$COOLDOWN_FILE"
        fi
    fi
    return 0
}

# Check if VPN is connected by pinging external hosts and verifying routing
# Returns 0 (success) if VPN is connected, 1 (failure) if disconnected
check_vpn() {
    # Check if tun0 interface exists first
    if ! ip addr show tun0 &>/dev/null; then
        log_warn "VPN interface tun0 not found"
        return 1
    fi

    # Check if the tun0 interface has an IP address
    if ! ip addr show tun0 | grep -q "inet "; then
        log_warn "VPN interface tun0 has no IP address"
        return 1
    fi

    # Check if we have proper routing through the VPN
    if ! ip route | grep -q "default.*tun0"; then
        log_warn "No default route through VPN tunnel"
        # Try to fix routing if possible
        if ip route show | grep -q "0.0.0.0/1"; then
            log_info "Found split tunnel routes, which is acceptable"
        else
            log_warn "No VPN routes found"
            return 1
        fi
    fi

    # Try multiple reliable hosts in case one is temporarily unavailable
    # Using more hosts and improved timeout settings
    FAILED_HOSTS=0
    TOTAL_HOSTS=4
    SUCCESS_NEEDED=1  # We only need one successful ping to consider connection up

    # Try to resolve DNS first to check for DNS functionality
    if ! nslookup google.com > /dev/null 2>&1; then
        log_warn "DNS resolution failed, possible DNS leak protection issue"
        # Don't fail immediately, still try direct IP pings
    fi

    for HOST in "10.8.0.1" "1.1.1.1" "8.8.8.8" "google.com"; do
        # More aggressive ping settings for better detection
        ping -c 2 -W 5 -i 0.5 $HOST > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_debug "Successfully pinged $HOST"
            return 0  # Connection successful with at least one host
        else
            log_debug "Failed to ping $HOST"
            FAILED_HOSTS=$((FAILED_HOSTS + 1))
        fi
    done

    # Only consider connection down if ALL hosts failed
    if [ $FAILED_HOSTS -eq $TOTAL_HOSTS ]; then
        log_warn "All ping attempts failed, VPN connection appears to be down"
        return 1
    else
        # Some hosts responded, connection is probably fine
        return 0
    fi
}

# Check if transmission daemon is running
# Returns 0 (success) if running, 1 (failure) if not running
check_transmission() {
    pgrep -x transmission-daemon > /dev/null
    return $?
}

# Check if we're in cooldown period
if ! check_cooldown; then
    log_info "In cooldown period, skipping VPN check"
    exit 0
fi

# Get current VPN server from the tracking file
# Fallback to "unknown" if the file doesn't exist or can't be read
CURRENT_SERVER=$(cat /etc/openvpn/custom/current_server.txt 2>/dev/null || echo "unknown")

log_info "Checking VPN connection to server: $CURRENT_SERVER"

# Check if VPN connection is active
if ! check_vpn; then
    log_warn "VPN connection appears to be down, performing additional checks"

    # Double-check after a short delay to avoid false positives
    log_info "Waiting 30 seconds before confirming connection status"
    sleep 30

    if ! check_vpn; then
        log_error "VPN connection is confirmed down. Stopping transmission and reconnecting..."

        # Stop transmission if it's running to prevent data leaks
        if check_transmission; then
            log_warn "Stopping transmission-daemon"
            pkill -15 transmission-daemon
            sleep 5
        fi

        # Set cooldown timestamp to prevent rapid reconnection attempts
        date +%s > "$COOLDOWN_FILE"
        log_info "Created cooldown timestamp, will not attempt reconnection for 15 minutes"

        # Check if server list exists and use it to find alternative servers
        if [ -f /etc/openvpn/custom/server_list.txt ]; then
            # Get list of available VPN servers from server_list.txt (excluding current one)
            SERVERS=($(grep -v "^$CURRENT_SERVER$" /etc/openvpn/custom/server_list.txt))

            if [ ${#SERVERS[@]} -eq 0 ]; then
                # No alternative servers found, try reconnecting to current server
                log_warn "No alternative VPN servers found in server_list.txt. Trying to reconnect to the current one."
                pkill -15 openvpn
                sleep 5
                /etc/openvpn/start.sh &
            else
                # Prioritize US servers if available (based on user preference)
                US_SERVERS=($(echo "${SERVERS[@]}" | tr ' ' '\n' | grep "^us\." | tr '\n' ' '))

                if [ ${#US_SERVERS[@]} -gt 0 ]; then
                    # Select a random US server for better distribution
                    log_info "Found US servers, prioritizing them"
                    NEXT_SERVER=${US_SERVERS[$RANDOM % ${#US_SERVERS[@]}]}
                else
                    # No US servers available, select a random server from the list
                    log_info "No US servers available, selecting from all available servers"
                    NEXT_SERVER=${SERVERS[$RANDOM % ${#SERVERS[@]}]}
                fi
            fi
        else
            # Fallback to scanning directory if server_list.txt doesn't exist
            log_warn "server_list.txt not found, scanning directory for .ovpn files"
            VPN_CONFIGS=($(ls /etc/openvpn/custom/*.ovpn | grep -v "$CURRENT_SERVER" | grep -v "default.ovpn"))

            if [ ${#VPN_CONFIGS[@]} -eq 0 ]; then
                # No alternative configs found, try reconnecting to current server
                log_warn "No alternative VPN configs found. Trying to reconnect to the current one."
                pkill -15 openvpn
                sleep 5
                /etc/openvpn/start.sh &
            else
                # Select a random config file
                NEXT_CONFIG=${VPN_CONFIGS[$RANDOM % ${#VPN_CONFIGS[@]}]}
                NEXT_SERVER=$(basename "$NEXT_CONFIG" .ovpn)
            fi
        fi

        # Update the current server tracking file
        log_info "Switching to VPN server: $NEXT_SERVER"
        echo "$NEXT_SERVER" > /etc/openvpn/custom/current_server.txt

        # Kill current OpenVPN process
        pkill -15 openvpn
        sleep 5

        # Set the new config as the active one
        export OPENVPN_CONFIG="$NEXT_SERVER"

        # Restart OpenVPN with the new server
        /etc/openvpn/start.sh &

        # Wait longer for VPN to connect
        log_info "Waiting for VPN connection to establish (45 seconds)"
        sleep 45

        # Check if reconnection was successful
        if check_vpn; then
            log_info "VPN reconnection successful"

            # Start transmission
            log_info "Starting transmission"
            /etc/transmission/start.sh &
        else
            log_error "VPN reconnection failed, will try again after cooldown period"
        fi
    fi
else
    # VPN connection is active
    log_info "VPN connection is up"

    # Make sure transmission is running if VPN is connected
    if ! check_transmission; then
        log_warn "Transmission is not running. Starting it..."
        /etc/transmission/start.sh &
    else
        log_debug "Transmission is running"
    fi
fi
