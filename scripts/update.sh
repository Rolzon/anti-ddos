#!/bin/bash

# Anti-DDoS Update Script
# Updates the Anti-DDoS system to the latest version

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

echo -e "${GREEN}=== Anti-DDoS Update ===${NC}"
echo

# Backup current configuration
echo -e "${GREEN}[1/6] Backing up current configuration...${NC}"
BACKUP_DIR="/backup/antiddos"
mkdir -p "$BACKUP_DIR"
DATE=$(date +%Y%m%d_%H%M%S)

if [ -d /etc/antiddos ]; then
    tar -czf "$BACKUP_DIR/antiddos-config-$DATE.tar.gz" /etc/antiddos/
    echo "Backup saved to: $BACKUP_DIR/antiddos-config-$DATE.tar.gz"
else
    echo "No existing configuration found"
fi

# Stop services
echo -e "${GREEN}[2/6] Stopping services...${NC}"
systemctl stop antiddos-monitor || true
systemctl stop antiddos-ssh || true
systemctl stop antiddos-xcord || true

# Update Python dependencies
echo -e "${GREEN}[3/6] Updating Python dependencies...${NC}"
pip3 install --upgrade -r requirements.txt

# Reinstall Python package
echo -e "${GREEN}[4/6] Updating Anti-DDoS package...${NC}"
pip3 install --upgrade -e .

# Update systemd services
echo -e "${GREEN}[5/6] Updating systemd services...${NC}"
cp systemd/antiddos-monitor.service /etc/systemd/system/
cp systemd/antiddos-ssh.service /etc/systemd/system/
cp systemd/antiddos-xcord.service /etc/systemd/system/
systemctl daemon-reload

# Restart services
echo -e "${GREEN}[6/6] Restarting services...${NC}"
systemctl start antiddos-monitor
systemctl start antiddos-ssh
systemctl start antiddos-xcord

echo
echo -e "${GREEN}=== Update Complete ===${NC}"
echo
echo "Services status:"
systemctl status antiddos-monitor --no-pager -l
echo
echo "Configuration backup: $BACKUP_DIR/antiddos-config-$DATE.tar.gz"
echo
echo "Check logs for any issues:"
echo "  sudo journalctl -u antiddos-monitor -f"
