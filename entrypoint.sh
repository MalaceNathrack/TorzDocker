#!/bin/bash
#
# Custom entrypoint script for TorzDocker
# This script initializes the cron service for VPN monitoring and rotation
# before executing the original entrypoint from the base image.
#

# Source the logging library
source /etc/scripts/logging.sh

# Log startup information
log_info "Starting TorzDocker container"
log_debug "Environment: LOG_LEVEL=${LOG_LEVEL}, LOG_TO_STDOUT=${LOG_TO_STDOUT}, LOG_FILE=${LOG_FILE}"

# Set up cron jobs with schedules from environment variables
# This configures the VPN rotation schedule and monitoring tasks
/etc/scripts/setup-cron.sh

# Start the cron service to enable scheduled tasks
# This is required for automatic VPN rotation and connection monitoring
service cron start

# Run network optimization script to improve performance
# This optimizes TCP/IP settings for better torrent throughput
/etc/scripts/network-optimize.sh

# Execute the original entrypoint from the base image
# This will start OpenVPN and Transmission with proper configuration
exec /etc/openvpn/start.sh
