#!/bin/bash

# Anti-DDoS Uninstallation Script
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

echo -e "${YELLOW}=== Anti-DDoS Uninstallation ===${NC}"
echo
echo -e "${YELLOW}This will remove all Anti-DDoS components${NC}"
read -p "Are you sure? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Stop services
echo -e "${GREEN}[1/6] Stopping services...${NC}"
systemctl stop antiddos-monitor || true
systemctl stop antiddos-ssh || true
systemctl stop antiddos-xcord || true

# Disable services
echo -e "${GREEN}[2/6] Disabling services...${NC}"
systemctl disable antiddos-monitor || true
systemctl disable antiddos-ssh || true
systemctl disable antiddos-xcord || true

# Remove systemd services
echo -e "${GREEN}[3/6] Removing systemd services...${NC}"
rm -f /etc/systemd/system/antiddos-monitor.service
rm -f /etc/systemd/system/antiddos-ssh.service
rm -f /etc/systemd/system/antiddos-xcord.service
systemctl daemon-reload

# Clean up firewall rules
echo -e "${GREEN}[4/6] Cleaning up firewall rules...${NC}"
iptables -D INPUT -j ANTIDDOS 2>/dev/null || true
iptables -F ANTIDDOS 2>/dev/null || true
iptables -X ANTIDDOS 2>/dev/null || true

# Remove Python package
echo -e "${GREEN}[5/6] Removing Python package...${NC}"
pip3 uninstall -y antiddos || true

# Remove CLI
echo -e "${GREEN}[6/6] Removing CLI...${NC}"
rm -f /usr/local/bin/antiddos-cli

echo
echo -e "${YELLOW}Configuration and logs preserved in:${NC}"
echo "  - /etc/antiddos/"
echo "  - /var/log/antiddos/"
echo
read -p "Remove configuration and logs? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf /etc/antiddos
    rm -rf /var/log/antiddos
    echo -e "${GREEN}Configuration and logs removed${NC}"
fi

echo
echo -e "${GREEN}=== Uninstallation Complete ===${NC}"
