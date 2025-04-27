#!/bin/bash
#
# prepare-protonvpn.sh - ProtonVPN Configuration Preparation Script
#
# This script prepares ProtonVPN OpenVPN configuration files for use with the container.
# It modifies the .ovpn files to prevent DNS leaks, creates a default configuration,
# and sets up the server rotation system.
#
# You must run this script before starting the container for the first time.
#

# Create necessary directories if they don't exist
mkdir -p openvpn    # For OpenVPN configuration files
mkdir -p config     # For persistent configuration
mkdir -p data       # For application data
mkdir -p data/watch # For torrent watch directory
mkdir -p scripts    # For script files

# Verify the OpenVPN configs directory exists
if [ ! -d "openvpn" ]; then
    echo "Error: openvpn directory not found"
    exit 1
fi

# Display instructions for the user
echo "This script will help you prepare ProtonVPN configuration files."
echo "You need to download the OpenVPN configuration files from your ProtonVPN account."
echo "Visit https://account.protonvpn.com/downloads and download the OpenVPN configuration files."
echo "Extract the downloaded ZIP file and place the .ovpn files in the 'openvpn' directory."
echo ""
echo "Press Enter when you have placed the .ovpn files in the 'openvpn' directory..."
read

# Check if there are any .ovpn files in the directory
OVPN_COUNT=$(ls openvpn/*.ovpn 2>/dev/null | wc -l)
if [ "$OVPN_COUNT" -eq 0 ]; then
    echo "Error: No .ovpn files found in the openvpn directory"
    exit 1
fi

echo "Found $OVPN_COUNT .ovpn files in the openvpn directory."

# Modify the .ovpn files to enhance security and prevent DNS leaks
echo "Modifying .ovpn files to prevent DNS leaks..."
for file in openvpn/*.ovpn; do
    # Remove block-outside-dns directive if it exists (not supported in Linux)
    # This directive is Windows-specific and will cause errors in Linux
    if grep -q "block-outside-dns" "$file"; then
        sed -i '/block-outside-dns/d' "$file"
    fi

    # Add redirect-gateway directive if it doesn't exist
    # This ensures all traffic goes through the VPN tunnel
    if ! grep -q "redirect-gateway def1" "$file"; then
        echo "redirect-gateway def1" >> "$file"
    fi

    # Add DNS settings to use ProtonVPN DNS servers
    # This prevents DNS leaks by using the VPN provider's DNS servers
    if ! grep -q "dhcp-option DNS 10.8.0.1" "$file"; then
        echo "dhcp-option DNS 10.8.0.1" >> "$file"
    fi

    echo "Modified: $file"
done

# Set up the initial VPN server
echo "Setting initial VPN server..."

# Check if there's a US server available (user preference)
# ProtonVPN names US servers with "us" prefix
US_SERVER=$(ls openvpn/us*.ovpn 2>/dev/null | head -1)

if [ -n "$US_SERVER" ]; then
    # Use a US server if available (preferred)
    FIRST_SERVER=$(basename "$US_SERVER" .ovpn)
    echo "Found US server, using it as initial server"
else
    # Fallback to any server if no US server is available
    FIRST_SERVER=$(basename "$(ls openvpn/*.ovpn | head -1)" .ovpn)
    echo "No US server found, using first available server"
fi

# Create a file to track the current server
echo "$FIRST_SERVER" > openvpn/current_server.txt
echo "Initial VPN server set to: $FIRST_SERVER"

# Create a default.ovpn file that the container will use on first start
echo "Creating default.ovpn file..."
cp "openvpn/$FIRST_SERVER.ovpn" openvpn/default.ovpn
echo "Created default.ovpn from $FIRST_SERVER.ovpn"

# Create a list of all available servers for rotation
echo "Creating server list..."
for file in openvpn/*.ovpn; do
    if [ "$(basename "$file")" != "default.ovpn" ]; then
        SERVER_NAME=$(basename "$file" .ovpn)
        echo "$SERVER_NAME" >> openvpn/server_list.txt
    fi
done
echo "Created server list with $(wc -l < openvpn/server_list.txt) servers"

# Display completion message and next steps
echo ""
echo "ProtonVPN configuration files have been prepared successfully."
echo "You can now start the container with 'docker-compose up -d'"
echo ""
echo "Make sure your .env file contains your ProtonVPN OpenVPN credentials."
echo "These are different from your regular ProtonVPN login credentials."
echo "You can find them at https://account.protonvpn.com/account#openvpn-ike2"
