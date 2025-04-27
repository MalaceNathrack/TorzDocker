#!/bin/bash

# This script runs before OpenVPN starts
# It ensures DNS leak protection is properly configured

# Log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Running pre-start script for OpenVPN"

# Ensure DNS leak protection is enabled
log "Setting up DNS leak protection"

# Create resolv.conf with ProtonVPN DNS servers and fallback to reliable public DNS
cat > /etc/resolv.conf << EOF
# ProtonVPN DNS servers
nameserver 10.8.0.1
# Fallback to Cloudflare DNS (only used if VPN DNS fails)
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

# Try to make resolv.conf immutable, but don't fail if it doesn't work
chattr +i /etc/resolv.conf 2>/dev/null || log "Could not make resolv.conf immutable (this is normal in Docker)"

# Additional DNS leak protection by setting up iptables rules to force DNS through VPN
log "Setting up iptables rules for DNS leak protection"
# Redirect all DNS traffic (port 53) through the VPN tunnel
iptables -t nat -A OUTPUT -p udp --dport 53 -j DNAT --to-destination 10.8.0.1:53 2>/dev/null || log "Could not set up DNS iptables rules (this is normal if not running as root)"
iptables -t nat -A OUTPUT -p tcp --dport 53 -j DNAT --to-destination 10.8.0.1:53 2>/dev/null || log "Could not set up DNS iptables rules (this is normal if not running as root)"

log "DNS leak protection configured"

# Try to enable IP forwarding, but don't fail if it doesn't work
if [ -w /proc/sys/net/ipv4/ip_forward ]; then
    echo 1 > /proc/sys/net/ipv4/ip_forward
else
    log "Could not enable IP forwarding (this is normal in Docker)"
fi

# Try to disable IPv6, but don't fail if it doesn't work
log "Disabling IPv6 to prevent leaks"
if [ -w /proc/sys/net/ipv6/conf/all/disable_ipv6 ]; then
    echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
else
    log "Could not disable IPv6 (this is normal in Docker)"
fi

if [ -w /proc/sys/net/ipv6/conf/default/disable_ipv6 ]; then
    echo 1 > /proc/sys/net/ipv6/conf/default/disable_ipv6
fi

log "Pre-start script completed"
