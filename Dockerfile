# Base image: haugene/transmission-openvpn provides a container with OpenVPN and Transmission
# already configured to work together with kill switch functionality
FROM haugene/transmission-openvpn:latest

# Install additional system tools:
# - cron: For scheduling VPN rotation and monitoring tasks
# - curl: For network requests and health checks
# - dnsutils: For DNS-related tools like dig and nslookup (DNS leak testing)
# - iputils-ping: For network connectivity testing
# Clean up after installation to reduce image size
RUN apt-get update && apt-get install -y \
    cron \
    curl \
    dnsutils \
    iputils-ping \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy custom scripts to the container:
# - logging.sh: Centralized logging system with log levels
# - vpn-monitor.sh: Monitors VPN connection and restarts if it drops
# - vpn-rotate.sh: Rotates between available VPN servers periodically
# - network-optimize.sh: Optimizes network settings for better performance
COPY scripts/logging.sh /etc/scripts/logging.sh
COPY scripts/vpn-monitor.sh /etc/scripts/vpn-monitor.sh
COPY scripts/vpn-rotate.sh /etc/scripts/vpn-rotate.sh
COPY scripts/network-optimize.sh /etc/scripts/network-optimize.sh

# Make the scripts executable
RUN chmod +x /etc/scripts/logging.sh /etc/scripts/vpn-monitor.sh /etc/scripts/vpn-rotate.sh /etc/scripts/network-optimize.sh

# Copy and make executable the cron setup script
# This script will configure cron jobs with schedules from environment variables
COPY scripts/setup-cron.sh /etc/scripts/setup-cron.sh
RUN chmod +x /etc/scripts/setup-cron.sh

# Set up the VPN monitoring cron job to run every minute
# This ensures quick detection and recovery from VPN connection failures
RUN echo "* * * * * /etc/scripts/vpn-monitor.sh >> /var/log/cron.log 2>&1" > /etc/cron.d/vpn-monitor \
    && chmod 0644 /etc/cron.d/vpn-monitor \
    && crontab /etc/cron.d/vpn-monitor

# Create log file for cron job output
RUN touch /var/log/cron.log

# Copy custom entrypoint script that starts cron service before
# executing the original entrypoint from the base image
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Use our custom entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
