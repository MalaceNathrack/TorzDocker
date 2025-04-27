#!/bin/bash
#
# setup.sh - TorzDocker Initial Setup Script
#
# This script performs the initial setup for the TorzDocker environment.
# It creates the necessary directory structure, sets up the environment file,
# and makes the scripts executable.
#

echo "Setting up TorzDocker environment..."

# Create necessary directories for the application
mkdir -p openvpn    # For OpenVPN configuration files
mkdir -p config     # For persistent configuration
mkdir -p data/watch # For torrent watch directory and other data
mkdir -p scripts    # For script files

# Check if .env file exists, if not create it from example
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        echo "Creating .env file from .env.example..."
        cp .env.example .env
        echo "Please edit the .env file with your ProtonVPN credentials."
    else
        echo "Error: .env.example file not found."
        echo "You need to create a .env file with your configuration settings."
        exit 1
    fi
fi

# Make all scripts executable
chmod +x scripts/*.sh

# Display next steps for the user
echo ""
echo "Initial setup complete!"
echo ""
echo "Next steps:"
echo "1. Download OpenVPN configuration files from your ProtonVPN account"
echo "   Visit https://account.protonvpn.com/downloads"
echo "2. Extract the .ovpn files to the 'openvpn' directory"
echo "3. Run ./scripts/prepare-protonvpn.sh to prepare the configuration files"
echo "4. Edit the .env file with your ProtonVPN credentials"
echo "   (These are your OpenVPN credentials, not your regular ProtonVPN login)"
echo "5. Start the container with 'docker-compose up -d'"
echo ""
echo "For more information, refer to the README.md file."
