# TorzDocker - Secure Torrenting with VPN

A Docker-based solution for secure torrenting through ProtonVPN with automatic server rotation, connection monitoring, and DNS leak protection.

## Overview

TorzDocker combines OpenVPN and Transmission BitTorrent client in a Docker container with enhanced security features. It automatically rotates between VPN servers, monitors the connection, and ensures all traffic is properly routed through the VPN tunnel.

## Features

- **Secure VPN Integration**: Uses OpenVPN with ProtonVPN for encrypted traffic
- **Automatic Server Rotation**: Switches between VPN servers every 6 hours (configurable)
- **Connection Monitoring**: Continuously checks VPN connection and reconnects if it drops
- **Server Prioritization**: Prefers US-based servers with fallback to other locations
- **Kill Switch**: Automatically stops torrent client if VPN connection drops
- **DNS Leak Protection**: Routes all DNS requests through the VPN provider's DNS servers
- **Bandwidth Control**: Configurable upload/download speed limits (default: 5KB/s upload, unlimited download)
- **Web Interface**: Transmission web UI accessible at http://localhost:9091
- **Persistent Storage**: Saves downloaded files to a configurable location on the host

## Prerequisites

- Docker and Docker Compose installed
- ProtonVPN account with OpenVPN credentials
- Downloaded OpenVPN configuration files from ProtonVPN

## Detailed Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/TorzDocker.git
cd TorzDocker
```

### 2. Run the Setup Script

This creates the necessary directory structure and configuration files:

```bash
chmod +x setup.sh
./setup.sh
```

### 3. Download and Prepare OpenVPN Configuration Files

1. Download the OpenVPN configuration files from your ProtonVPN account:
   - Go to https://account.protonvpn.com/downloads
   - Download the OpenVPN configuration files (UDP is recommended for better performance)
   - Extract the ZIP file
   - Copy the `.ovpn` files to the `openvpn` directory in your TorzDocker folder

2. Run the preparation script to configure the OpenVPN files:
   ```bash
   ./scripts/prepare-protonvpn.sh
   ```

   This script:
   - Modifies the `.ovpn` files to prevent DNS leaks
   - Sets up the initial VPN server (preferring US servers if available)
   - Creates a list of available servers for rotation

### 4. Configure Environment Variables

Edit the `.env` file with your ProtonVPN credentials and customize settings:

```
# ProtonVPN Credentials
# These are your OpenVPN credentials from https://account.protonvpn.com/account#openvpn-ike2
# NOT your regular ProtonVPN login credentials
OPENVPN_USERNAME=your_openvpn_username
OPENVPN_PASSWORD=your_openvpn_password

# Network Configuration
LOCAL_NETWORK=192.168.0.0/16

# Path Configuration
DOWNLOADS_PATH=c:/downloads

# Other settings can be left at their defaults
```

> **Important**: For the `OPENVPN_USERNAME` and `OPENVPN_PASSWORD`, use your OpenVPN credentials from ProtonVPN, not your regular ProtonVPN account credentials. You can find these at https://account.protonvpn.com/account#openvpn-ike2

### 5. Start the Container

```bash
docker-compose up -d
```

To see the logs and verify everything is working:
```bash
docker-compose logs -f
```

### 6. Access the Transmission Web Interface

Open http://localhost:9091 in your web browser to access the Transmission web interface.

Default credentials (if prompted):
- Username: `transmission`
- Password: `transmission`

You can change these by adding environment variables in the docker-compose.yml file.

## How It Works

### VPN Connection Management

1. **Initial Connection**: The container connects to the VPN using the default server (preferably a US server)
2. **Connection Monitoring**: A cron job runs every minute to check if the VPN connection is active
3. **Automatic Reconnection**: If the connection drops, the system stops Transmission and connects to a different server
4. **Server Rotation**: Every 6 hours (configurable), the system rotates to a different VPN server for better privacy

### Security Measures

1. **Kill Switch**: If the VPN connection drops, Transmission is immediately stopped to prevent data leaks
2. **DNS Leak Protection**: All DNS requests are routed through the VPN provider's DNS servers
3. **Traffic Routing**: All traffic is forced through the VPN tunnel using the `redirect-gateway def1` directive

### Directory Structure

- `openvpn/`: Contains OpenVPN configuration files
- `config/`: Stores persistent configuration for Transmission
- `data/`: Contains application data and watch directory for .torrent files
- `scripts/`: Contains scripts for VPN monitoring, rotation, and setup

## Advanced Configuration

### Customizing VPN Rotation Schedule

Edit the `VPN_ROTATION_SCHEDULE` variable in the `.env` file. The default is every 6 hours:

```
# Format: minute hour day-of-month month day-of-week
VPN_ROTATION_SCHEDULE=0 */6 * * *
```

### Changing Bandwidth Limits

Edit the following variables in the `.env` file:

```
# Upload speed limit in KB/s (5 = 5 KB/s)
TRANSMISSION_SPEED_LIMIT_UP=5
TRANSMISSION_SPEED_LIMIT_UP_ENABLED=true

# Download speed limit in KB/s (0 = unlimited)
TRANSMISSION_SPEED_LIMIT_DOWN=0
TRANSMISSION_SPEED_LIMIT_DOWN_ENABLED=false
```

### Changing Download Location

Edit the `DOWNLOADS_PATH` variable in the `.env` file:

```
DOWNLOADS_PATH=/path/to/your/downloads
```

## Troubleshooting

### Common Issues

#### Container Exits Immediately

If the container exits immediately after starting, check the logs for errors:

```bash
docker-compose logs
```

Common reasons for this include:
- Missing or incorrectly named OpenVPN configuration files
- Incorrect ProtonVPN credentials
- Network connectivity issues

#### "Supplied config default.ovpn could not be found"

This means the container can't find the OpenVPN configuration file. Make sure:
1. You've copied the `.ovpn` files to the 'openvpn' directory
2. You've run the `prepare-protonvpn.sh` script
3. The `default.ovpn` file was created correctly (check if `openvpn/default.ovpn` exists)

If the file doesn't exist, you can manually create it:
```bash
cp openvpn/your-first-server.ovpn openvpn/default.ovpn
```
Replace 'your-first-server.ovpn' with the name of one of your `.ovpn` files.

#### "WARNING: initial DNS resolution test failed"

This is usually not a critical error and the container should still work. It happens because the container tries to resolve DNS before the VPN connection is established.

### Useful Commands

#### Viewing Container Logs

```bash
docker-compose logs -f
```

#### Manual VPN Rotation

To manually rotate the VPN server:

```bash
docker exec torzvpn /etc/scripts/vpn-rotate.sh
```

#### Checking VPN Status

To check if the VPN connection is active:

```bash
docker exec torzvpn ping -c 1 google.com
```

#### Restarting the Container

```bash
docker-compose restart
```

#### Rebuilding the Container

If you've made changes to the Dockerfile or scripts:

```bash
docker-compose down
docker-compose build
docker-compose up -d
```

## Security Considerations

- **VPN Kill Switch**: If the VPN connection drops, the torrent client is automatically stopped
- **DNS Leak Protection**: All DNS requests are routed through the VPN provider's DNS servers
- **Traffic Routing**: All traffic is forced through the VPN tunnel
- **Credential Security**: Store your VPN credentials securely and never commit them to version control
- **Regular Updates**: Keep the base image and all components updated regularly

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
