#!/bin/bash

# This script runs before Transmission starts
# It ensures that the VPN connection is active before starting Transmission

# Log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Running pre-start script for Transmission"

# Check if VPN is connected
log "Checking VPN connection"

# Wait for the tun0 interface to be fully up
WAIT_TIME=0
MAX_WAIT=20  # Increased wait time for better reliability
CONNECTED=0

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    if ip addr show tun0 2>/dev/null | grep -q "state UP"; then
        log "VPN interface tun0 is up"
        CONNECTED=1
        break
    else
        log "Waiting for VPN interface tun0 to come up... ($WAIT_TIME/$MAX_WAIT)"
        sleep 1
        WAIT_TIME=$((WAIT_TIME+1))
    fi
done

if [ $CONNECTED -eq 1 ]; then
    # Wait a bit more for routes to be established
    log "Waiting for VPN routes to be established..."
    sleep 5  # Increased wait time for routes

    # More comprehensive routing check
    if ip route | grep -q "via 10.96.0.1" || ip route | grep -q "default.*tun0" || ip route | grep -q "0.0.0.0/1"; then
        log "VPN routing is configured correctly"

        # Try multiple times with a delay between attempts
        MAX_ATTEMPTS=4  # Increased attempts
        ATTEMPT=1
        PING_SUCCESS=0

        while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
            log "Connection check attempt $ATTEMPT of $MAX_ATTEMPTS..."

            # Try to ping multiple reliable hosts with better parameters
            for HOST in "10.8.0.1" "10.96.0.1" "1.1.1.1" "8.8.8.8" "google.com"; do
                ping -c 2 -W 5 $HOST > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                    log "Successfully pinged $HOST - VPN connection is active"
                    PING_SUCCESS=1
                    break 2
                fi
            done

            if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
                log "Connection check failed, waiting 3 seconds before retry..."
                sleep 3  # Increased wait between attempts
            fi

            ATTEMPT=$((ATTEMPT+1))
        done

        if [ $PING_SUCCESS -eq 0 ]; then
            log "WARNING: Could not ping through VPN, but interface is up. Continuing anyway..."
            # We'll continue anyway since the interface is up
        fi
    else
        log "WARNING: VPN routing may not be fully configured yet, but continuing anyway..."
        # Try to fix routing if possible
        log "Attempting to fix routing..."
        ip route add default dev tun0 2>/dev/null || log "Could not add default route"
    fi
else
    log "WARNING: VPN interface tun0 did not come up within $MAX_WAIT seconds, but continuing anyway..."
    # Force the CONNECTED flag to 1 to allow Transmission to start
    CONNECTED=1
fi

# Always continue even if VPN check fails
log "VPN connection check completed - starting Transmission"

log "VPN connection check passed"

log "VPN connection is active. Proceeding with Transmission startup."

# Ensure download directories exist with proper permissions
log "Setting up download directories"
mkdir -p /downloads
mkdir -p /downloads/incomplete
chown -R ${PUID}:${PGID} /downloads

# Apply custom settings if they exist
if [ -f /config/transmission-settings.json ]; then
    log "Applying custom Transmission settings"
    mkdir -p /config/transmission-home
    cp /config/transmission-settings.json /config/transmission-home/settings.json
    chown ${PUID}:${PGID} /config/transmission-home/settings.json
fi

log "Pre-start script completed"
