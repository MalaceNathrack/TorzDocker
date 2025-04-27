#!/bin/bash
#
# network-optimize.sh - Network Optimization Script
#
# This script optimizes network settings for better torrent performance
# It adjusts TCP/IP parameters and buffer sizes for improved throughput
#

# Log function with timestamp for better log readability
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Running network optimization script"

# Increase TCP window size
log "Optimizing TCP window size"
if [ -w /proc/sys/net/core/rmem_max ]; then
    echo 4194304 > /proc/sys/net/core/rmem_max
    echo 4194304 > /proc/sys/net/core/wmem_max
    log "TCP window size increased to 4MB"
else
    log "Could not adjust TCP window size (this is normal in Docker)"
fi

# Increase the maximum number of open files
log "Increasing maximum open files limit"
ulimit -n 4096 2>/dev/null || log "Could not increase open files limit"

# Optimize TCP congestion control
log "Setting TCP congestion control to BBR if available"
if [ -w /proc/sys/net/ipv4/tcp_congestion_control ]; then
    # Check if BBR is available
    if grep -q bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
        echo "bbr" > /proc/sys/net/ipv4/tcp_congestion_control
        log "TCP congestion control set to BBR"
    else
        # Fallback to cubic which is also good
        echo "cubic" > /proc/sys/net/ipv4/tcp_congestion_control
        log "TCP congestion control set to CUBIC (BBR not available)"
    fi
else
    log "Could not adjust TCP congestion control (this is normal in Docker)"
fi

# Enable TCP Fast Open if available
if [ -w /proc/sys/net/ipv4/tcp_fastopen ]; then
    echo 3 > /proc/sys/net/ipv4/tcp_fastopen
    log "TCP Fast Open enabled"
fi

# Increase UDP buffer size for better throughput
if [ -w /proc/sys/net/ipv4/udp_rmem_min ]; then
    echo 8192 > /proc/sys/net/ipv4/udp_rmem_min
    log "UDP receive buffer minimum size increased"
fi

# Optimize network interface settings for the VPN tunnel
log "Optimizing VPN tunnel interface"
if ip link show tun0 &>/dev/null; then
    # Increase MTU if possible (careful with this as it can cause fragmentation issues)
    # ip link set tun0 mtu 1500 2>/dev/null || log "Could not adjust MTU"
    
    # Increase the TX queue length
    ip link set tun0 txqueuelen 1000 2>/dev/null || log "Could not adjust txqueuelen"
    log "VPN tunnel interface optimized"
else
    log "VPN tunnel interface not found, skipping optimization"
fi

log "Network optimization completed"
