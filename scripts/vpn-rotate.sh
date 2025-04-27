#!/bin/bash
#
# vpn-rotate.sh - VPN Server Rotation Script
#
# This script rotates the VPN connection to a different server on a schedule.
# It prioritizes US-based servers when available, falling back to other servers
# if necessary. The script ensures that the torrent client is stopped during
# the transition to prevent data leaks.
#

# Source the logging library
source /etc/scripts/logging.sh

# Get current VPN server from the tracking file
# Fallback to "unknown" if the file doesn't exist or can't be read
CURRENT_SERVER=$(cat /etc/openvpn/custom/current_server.txt 2>/dev/null || echo "unknown")
log_info "Current VPN server: $CURRENT_SERVER"

# Check if server list exists and use it to find alternative servers
if [ -f /etc/openvpn/custom/server_list.txt ]; then
    # Get list of available VPN servers from server_list.txt (excluding current one)
    # This prevents rotating to the same server we're already connected to
    SERVERS=($(grep -v "^$CURRENT_SERVER$" /etc/openvpn/custom/server_list.txt))

    if [ ${#SERVERS[@]} -eq 0 ]; then
        # No alternative servers found, stay on current server
        log_warn "No alternative VPN servers found in server_list.txt. Staying on current server."
        exit 0
    fi

    # Prioritize US servers if available (based on user preference)
    # This looks for server names starting with "us." which is the ProtonVPN naming convention
    US_SERVERS=($(echo "${SERVERS[@]}" | tr ' ' '\n' | grep "^us\." | tr '\n' ' '))

    if [ ${#US_SERVERS[@]} -gt 0 ]; then
        # Select a random US server for better distribution and privacy
        log_info "Found US servers, prioritizing them"
        NEXT_SERVER=${US_SERVERS[$RANDOM % ${#US_SERVERS[@]}]}
    else
        # No US servers available, select a random server from the list
        log_info "No US servers available, selecting from all available servers"
        NEXT_SERVER=${SERVERS[$RANDOM % ${#SERVERS[@]}]}
    fi
else
    # Fallback to scanning directory if server_list.txt doesn't exist
    # This is a more expensive operation but ensures we can still rotate servers
    log_warn "server_list.txt not found, scanning directory for .ovpn files"
    VPN_CONFIGS=($(ls /etc/openvpn/custom/*.ovpn | grep -v "$CURRENT_SERVER" | grep -v "default.ovpn"))

    if [ ${#VPN_CONFIGS[@]} -eq 0 ]; then
        # No alternative configs found, stay on current server
        log_warn "No alternative VPN configs found. Staying on current server."
        exit 0
    fi

    # Select a random config file
    NEXT_CONFIG=${VPN_CONFIGS[$RANDOM % ${#VPN_CONFIGS[@]}]}
    NEXT_SERVER=$(basename "$NEXT_CONFIG" .ovpn)
fi

log_info "Rotating VPN connection from $CURRENT_SERVER to $NEXT_SERVER"

# Stop transmission to prevent data leaks during VPN transition
log_warn "Stopping transmission-daemon"
pkill -15 transmission-daemon
sleep 5

# Update the current server tracking file
echo "$NEXT_SERVER" > /etc/openvpn/custom/current_server.txt

# Kill current OpenVPN process
log_info "Stopping OpenVPN"
pkill -15 openvpn
sleep 5

# Set the new config as the active one for the OpenVPN start script
export OPENVPN_CONFIG="$NEXT_SERVER"

# Restart OpenVPN with the new server
log_info "Starting OpenVPN with new server"
/etc/openvpn/start.sh &

# Wait for VPN to connect before starting transmission
# This ensures we don't leak any data during the transition
log_info "Waiting for VPN connection to establish..."

# More robust connection check with multiple attempts
MAX_ATTEMPTS=5
ATTEMPT=1
CONNECTED=0

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    log "Connection check attempt $ATTEMPT of $MAX_ATTEMPTS..."

    # Wait between attempts with increasing delay
    WAIT_TIME=$((10 + 5 * $ATTEMPT))
    sleep $WAIT_TIME

    # Check if tun0 interface exists and has an IP
    if ip addr show tun0 2>/dev/null | grep -q "inet "; then
        # Check routing
        if ip route | grep -q "default.*tun0" || ip route show | grep -q "0.0.0.0/1"; then
            # Try multiple hosts for ping test
            for HOST in "10.8.0.1" "1.1.1.1" "8.8.8.8" "google.com"; do
                ping -c 2 -W 5 $HOST > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                    log "Successfully pinged $HOST - VPN connection is active"
                    CONNECTED=1
                    break 2
                fi
            done
        else
            log "VPN routing not established yet"
        fi
    else
        log "VPN interface not ready yet"
    fi

    ATTEMPT=$((ATTEMPT + 1))
done

if [ $CONNECTED -eq 1 ]; then
    # VPN connection successful, safe to start transmission
    log "VPN connection established successfully"
    log "Starting transmission-daemon"
    /etc/transmission/start.sh &
else
    # VPN connection failed after multiple attempts, run the monitor script to recover
    log "Failed to establish VPN connection after $MAX_ATTEMPTS attempts. Running vpn-monitor.sh to recover..."
    /etc/scripts/vpn-monitor.sh
fi
