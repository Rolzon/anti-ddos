#!/bin/bash

# Anti-DDoS Installation Script for Ubuntu 22.04
# Must be run as root

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Check Ubuntu version
if ! grep -q "22.04" /etc/os-release; then
    echo -e "${YELLOW}Warning: This script is designed for Ubuntu 22.04${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}=== Anti-DDoS Installation ===${NC}"
echo

# Update package list
echo -e "${GREEN}[1/8] Updating package list...${NC}"
apt-get update -qq

# Install system dependencies
echo -e "${GREEN}[2/8] Installing system dependencies...${NC}"
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    iptables \
    iptables-persistent \
    conntrack \
    net-tools \
    curl \
    wget

# Install Python dependencies
echo -e "${GREEN}[3/8] Installing Python dependencies...${NC}"
pip3 install -r requirements.txt

# Create directories
echo -e "${GREEN}[4/8] Creating directories...${NC}"
mkdir -p /etc/antiddos
mkdir -p /var/log/antiddos
mkdir -p /usr/share/GeoIP

# Copy configuration
echo -e "${GREEN}[5/8] Installing configuration...${NC}"
if [ -f /etc/antiddos/config.yaml ]; then
    echo -e "${YELLOW}Configuration file already exists, backing up...${NC}"
    cp /etc/antiddos/config.yaml /etc/antiddos/config.yaml.backup.$(date +%Y%m%d_%H%M%S)
fi
cp config/config.yaml /etc/antiddos/config.yaml

# Create empty blacklist and whitelist files
touch /etc/antiddos/blacklist.txt
touch /etc/antiddos/whitelist.txt

# Install Python package
echo -e "${GREEN}[6/8] Installing Anti-DDoS package...${NC}"
pip3 install -e .

# Install systemd services
echo -e "${GREEN}[7/8] Installing systemd services...${NC}"
cp systemd/antiddos-monitor.service /etc/systemd/system/
cp systemd/antiddos-ssh.service /etc/systemd/system/
cp systemd/antiddos-xcord.service /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Create CLI symlink
echo -e "${GREEN}[8/8] Creating CLI symlink...${NC}"
ln -sf $(which python3) /usr/local/bin/antiddos-cli
cat > /usr/local/bin/antiddos-cli << 'EOF'
#!/usr/bin/python3
import sys
from antiddos.cli import main
sys.exit(main())
EOF
chmod +x /usr/local/bin/antiddos-cli

echo
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo
echo -e "${YELLOW}Important: Please configure the following:${NC}"
echo
echo "1. Edit /etc/antiddos/config.yaml and configure:"
echo "   - Network interface (bandwidth.interface)"
echo "   - Country filters (country_filter.blacklist)"
echo "   - XCord encryption key (xcord.encryption_key)"
echo "   - XCord auth token (xcord.auth_token)"
echo
echo "2. Add your trusted IPs to whitelist:"
echo "   sudo antiddos-cli whitelist add YOUR_IP"
echo
echo "3. Download GeoIP database (requires MaxMind account):"
echo "   Visit: https://www.maxmind.com/en/geolite2/signup"
echo "   Then: sudo antiddos-cli geoip update"
echo
echo "4. Start the services:"
echo "   sudo systemctl start antiddos-monitor"
echo "   sudo systemctl start antiddos-ssh"
echo "   sudo systemctl start antiddos-xcord"
echo
echo "5. Enable services on boot:"
echo "   sudo systemctl enable antiddos-monitor"
echo "   sudo systemctl enable antiddos-ssh"
echo "   sudo systemctl enable antiddos-xcord"
echo
echo "6. Check status:"
echo "   sudo systemctl status antiddos-monitor"
echo "   sudo antiddos-cli stats"
echo
echo -e "${GREEN}For more information, see README.md${NC}"
