#!/bin/bash

# Quick Setup Script for Anti-DDoS
# Interactive configuration wizard

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Anti-DDoS Quick Setup Wizard        ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Check if already installed
if ! command -v antiddos-cli &> /dev/null; then
    echo -e "${RED}Error: Anti-DDoS is not installed yet.${NC}"
    echo "Please run: sudo ./install.sh"
    exit 1
fi

echo -e "${GREEN}Anti-DDoS is installed. Let's configure it!${NC}"
echo

# 1. Get network interface
echo -e "${YELLOW}[1/7] Network Interface${NC}"
echo "Available network interfaces:"
ip -o link show | awk -F': ' '{print "  - " $2}'
echo
read -p "Enter your primary network interface (e.g., eth0, ens3): " INTERFACE

if ! ip a show "$INTERFACE" &>/dev/null; then
    echo -e "${RED}Error: Interface $INTERFACE not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Using interface: $INTERFACE${NC}"
echo

# 2. Get admin IP
echo -e "${YELLOW}[2/7] Admin IP Whitelist${NC}"
echo "Your current IP address appears to be:"
CURRENT_IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unable to detect")
echo "  $CURRENT_IP"
echo
read -p "Enter your admin IP to whitelist (press Enter to use detected IP): " ADMIN_IP
ADMIN_IP=${ADMIN_IP:-$CURRENT_IP}

if [[ ! $ADMIN_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Invalid IP address${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Will whitelist: $ADMIN_IP${NC}"
echo

# 3. Additional trusted IPs
echo -e "${YELLOW}[3/7] Additional Trusted IPs${NC}"
echo "Do you have other servers that need to communicate with this one?"
echo "(e.g., Pterodactyl panel, Wings servers, application servers)"
read -p "Enter additional IPs to whitelist (comma-separated, or press Enter to skip): " ADDITIONAL_IPS

TRUSTED_IPS=("$ADMIN_IP")
if [ -n "$ADDITIONAL_IPS" ]; then
    IFS=',' read -ra IPS <<< "$ADDITIONAL_IPS"
    for ip in "${IPS[@]}"; do
        ip=$(echo "$ip" | xargs)  # trim whitespace
        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            TRUSTED_IPS+=("$ip")
        fi
    done
fi

echo -e "${GREEN}✓ Trusted IPs: ${TRUSTED_IPS[*]}${NC}"
echo

# 4. Bandwidth thresholds
echo -e "${YELLOW}[4/7] Bandwidth Thresholds${NC}"
echo "What is your server's bandwidth capacity?"
echo "  1) 100 Mbps (small VPS)"
echo "  2) 1 Gbps (standard server)"
echo "  3) 10 Gbps (high-performance server)"
echo "  4) Custom"
read -p "Select option [1-4]: " BW_OPTION

case $BW_OPTION in
    1)
        BW_THRESHOLD=80
        PPS_THRESHOLD=50000
        ;;
    2)
        BW_THRESHOLD=800
        PPS_THRESHOLD=100000
        ;;
    3)
        BW_THRESHOLD=8000
        PPS_THRESHOLD=500000
        ;;
    4)
        read -p "Enter bandwidth threshold in Mbps: " BW_THRESHOLD
        read -p "Enter PPS threshold: " PPS_THRESHOLD
        ;;
    *)
        echo "Invalid option, using defaults (1 Gbps)"
        BW_THRESHOLD=800
        PPS_THRESHOLD=100000
        ;;
esac

echo -e "${GREEN}✓ Bandwidth threshold: ${BW_THRESHOLD} Mbps${NC}"
echo -e "${GREEN}✓ PPS threshold: ${PPS_THRESHOLD}${NC}"
echo

# 5. Country blocking
echo -e "${YELLOW}[5/7] Country Blocking${NC}"
echo "Do you want to enable country-based blocking?"
read -p "Enable country blocking? [Y/n]: " ENABLE_COUNTRY
ENABLE_COUNTRY=${ENABLE_COUNTRY:-Y}

COUNTRY_FILTER="false"
BLOCKED_COUNTRIES=""

if [[ $ENABLE_COUNTRY =~ ^[Yy]$ ]]; then
    COUNTRY_FILTER="true"
    echo "Common countries to block (for DDoS protection):"
    echo "  CN (China), RU (Russia), KP (North Korea), IR (Iran)"
    read -p "Enter country codes to block (comma-separated) or press Enter for defaults: " COUNTRIES
    
    if [ -z "$COUNTRIES" ]; then
        BLOCKED_COUNTRIES="CN, RU, KP, IR"
    else
        BLOCKED_COUNTRIES="$COUNTRIES"
    fi
    
    echo -e "${GREEN}✓ Will block countries: $BLOCKED_COUNTRIES${NC}"
else
    echo -e "${YELLOW}Country blocking disabled${NC}"
fi
echo

# 6. SSH protection
echo -e "${YELLOW}[6/7] SSH Protection${NC}"
read -p "Enable SSH failed attempt protection? [Y/n]: " ENABLE_SSH
ENABLE_SSH=${ENABLE_SSH:-Y}

SSH_ENABLED="false"
if [[ $ENABLE_SSH =~ ^[Yy]$ ]]; then
    SSH_ENABLED="true"
    echo -e "${GREEN}✓ SSH protection enabled${NC}"
else
    echo -e "${YELLOW}SSH protection disabled${NC}"
fi
echo

# 7. XCord (multi-server)
echo -e "${YELLOW}[7/7] XCord Multi-Server Setup${NC}"
echo "Do you have multiple servers that should share blacklists?"
read -p "Enable XCord? [y/N]: " ENABLE_XCORD
ENABLE_XCORD=${ENABLE_XCORD:-N}

XCORD_ENABLED="false"
XCORD_KEY=""
XCORD_TOKEN=""
XCORD_PEERS=""

if [[ $ENABLE_XCORD =~ ^[Yy]$ ]]; then
    XCORD_ENABLED="true"
    
    echo "Generating secure keys..."
    XCORD_KEY=$(openssl rand -base64 32)
    XCORD_TOKEN=$(openssl rand -hex 32)
    
    echo -e "${GREEN}✓ Generated encryption key: ${XCORD_KEY:0:20}...${NC}"
    echo -e "${GREEN}✓ Generated auth token: ${XCORD_TOKEN:0:20}...${NC}"
    
    echo
    echo "IMPORTANT: Save these keys! You'll need them on other servers:"
    echo "  Encryption Key: $XCORD_KEY"
    echo "  Auth Token: $XCORD_TOKEN"
    echo
    
    read -p "Enter peer server IPs (comma-separated, with :9999 port): " PEERS
    XCORD_PEERS="$PEERS"
    
    echo -e "${GREEN}✓ XCord enabled${NC}"
else
    echo -e "${YELLOW}XCord disabled (single server mode)${NC}"
fi
echo

# Summary
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Configuration Summary                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo
echo "Network Interface: $INTERFACE"
echo "Admin IP: $ADMIN_IP"
echo "Additional IPs: ${#TRUSTED_IPS[@]} total"
echo "Bandwidth Threshold: ${BW_THRESHOLD} Mbps"
echo "PPS Threshold: ${PPS_THRESHOLD}"
echo "Country Blocking: $COUNTRY_FILTER"
if [[ $COUNTRY_FILTER == "true" ]]; then
    echo "  Blocked Countries: $BLOCKED_COUNTRIES"
fi
echo "SSH Protection: $SSH_ENABLED"
echo "XCord: $XCORD_ENABLED"
echo

read -p "Apply this configuration? [Y/n]: " CONFIRM
CONFIRM=${CONFIRM:-Y}

if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "Configuration cancelled"
    exit 0
fi

# Apply configuration
echo
echo -e "${GREEN}Applying configuration...${NC}"

# Update config.yaml
CONFIG_FILE="/etc/antiddos/config.yaml"

# Backup original
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# Update interface
sed -i "s/interface: .*/interface: $INTERFACE/" "$CONFIG_FILE"

# Update thresholds
sed -i "s/threshold_mbps: .*/threshold_mbps: $BW_THRESHOLD/" "$CONFIG_FILE"
sed -i "s/threshold_pps: .*/threshold_pps: $PPS_THRESHOLD/" "$CONFIG_FILE"

# Update country filter
sed -i "s/enabled: true  # country_filter/enabled: $COUNTRY_FILTER/" "$CONFIG_FILE"

# Update SSH protection
sed -i "s/enabled: true  # ssh_protection/enabled: $SSH_ENABLED/" "$CONFIG_FILE"

# Update XCord
sed -i "s/enabled: true  # xcord/enabled: $XCORD_ENABLED/" "$CONFIG_FILE"
if [[ $XCORD_ENABLED == "true" ]]; then
    sed -i "s/encryption_key: .*/encryption_key: \"$XCORD_KEY\"/" "$CONFIG_FILE"
    sed -i "s/auth_token: .*/auth_token: \"$XCORD_TOKEN\"/" "$CONFIG_FILE"
fi

echo -e "${GREEN}✓ Configuration file updated${NC}"

# Add IPs to whitelist
echo "Adding IPs to whitelist..."
for ip in "${TRUSTED_IPS[@]}"; do
    antiddos-cli whitelist add "$ip" 2>/dev/null || true
    echo -e "${GREEN}✓ Whitelisted: $ip${NC}"
done

# Restart services
echo
echo "Restarting services..."
systemctl restart antiddos-monitor
systemctl restart antiddos-ssh
systemctl restart antiddos-xcord

echo
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Setup Complete!                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo
echo "Next steps:"
echo "  1. Check service status: sudo systemctl status antiddos-monitor"
echo "  2. View statistics: sudo antiddos-cli stats"
echo "  3. Monitor logs: sudo journalctl -u antiddos-monitor -f"
echo
echo "Configuration saved to: $CONFIG_FILE"
echo "Backup saved to: ${CONFIG_FILE}.backup.*"
echo

if [[ $XCORD_ENABLED == "true" ]]; then
    echo -e "${YELLOW}IMPORTANT: XCord Keys (save these!)${NC}"
    echo "  Encryption Key: $XCORD_KEY"
    echo "  Auth Token: $XCORD_TOKEN"
    echo
    echo "Use these same keys on all your servers!"
    echo
fi

echo "For more help, see:"
echo "  - /opt/anti-ddos/LEEME.md (Spanish)"
echo "  - /opt/anti-ddos/README.md (English)"
echo "  - /opt/anti-ddos/docs/PTERODACTYL_DEPLOYMENT.md"
