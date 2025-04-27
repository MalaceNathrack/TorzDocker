#!/bin/bash
#
# setup-cron.sh - Configure scheduled tasks for VPN management
#
# This script sets up cron jobs for VPN rotation and monitoring.
# It uses environment variables to determine the rotation schedule,
# with a default of every 6 hours if not specified.
#

# Source the logging library
source /etc/scripts/logging.sh

# Get VPN rotation schedule from environment variable or use default (every 6 hours)
# Format: minute hour day-of-month month day-of-week
# Default: "0 */6 * * *" = At minute 0 of every 6th hour
VPN_ROTATION_SCHEDULE=${VPN_ROTATION_SCHEDULE:-"0 */6 * * *"}

log_info "Setting up cron jobs"

# Set up VPN rotation cron job with the configured schedule
# This job will periodically switch to a different VPN server for better privacy
log_info "Setting up VPN rotation cron job with schedule: $VPN_ROTATION_SCHEDULE"
echo "$VPN_ROTATION_SCHEDULE /etc/scripts/vpn-rotate.sh >> $LOG_FILE 2>&1" > /etc/cron.d/vpn-rotate
chmod 0644 /etc/cron.d/vpn-rotate

# Set up VPN monitoring cron job to run every 3 minutes
# This job checks if the VPN connection is active and reconnects if necessary
# The improved vpn-monitor.sh has better cooldown handling to prevent excessive reconnections
log_info "Setting up VPN monitoring cron job (every 3 minutes)"
echo "*/3 * * * * /etc/scripts/vpn-monitor.sh >> $LOG_FILE 2>&1" > /etc/cron.d/vpn-monitor
chmod 0644 /etc/cron.d/vpn-monitor

# Apply cron jobs to the system
log_debug "Applying cron jobs to system crontab"
cat /etc/cron.d/vpn-rotate /etc/cron.d/vpn-monitor > /tmp/crontab
crontab /tmp/crontab

log_info "Cron jobs set up successfully"
