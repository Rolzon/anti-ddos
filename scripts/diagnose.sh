#!/bin/bash

# Anti-DDoS Diagnostic Script
# Run this to diagnose issues with the Anti-DDoS system

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Anti-DDoS Diagnostic Tool ===${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Warning: Not running as root. Some checks may fail.${NC}"
    echo
fi

# 1. Service Status
echo -e "${YELLOW}[1] Service Status${NC}"
echo "-------------------"
for service in antiddos-monitor antiddos-ssh antiddos-xcord; do
    if systemctl is-active --quiet $service; then
        echo -e "${GREEN}✓${NC} $service: Running"
    else
        echo -e "${RED}✗${NC} $service: Not running"
    fi
done
echo

# 2. Configuration
echo -e "${YELLOW}[2] Configuration${NC}"
echo "-------------------"
if [ -f /etc/antiddos/config.yaml ]; then
    echo -e "${GREEN}✓${NC} Configuration file exists"
    
    # Check if default keys are still in use
    if grep -q "CHANGE_THIS" /etc/antiddos/config.yaml; then
        echo -e "${RED}✗${NC} WARNING: Default XCord keys detected! Change them in config.yaml"
    else
        echo -e "${GREEN}✓${NC} XCord keys have been changed"
    fi
    
    # Check network interface
    interface=$(grep "interface:" /etc/antiddos/config.yaml | awk '{print $2}')
    if ip a show $interface &>/dev/null; then
        echo -e "${GREEN}✓${NC} Network interface '$interface' exists"
    else
        echo -e "${RED}✗${NC} Network interface '$interface' not found!"
    fi
else
    echo -e "${RED}✗${NC} Configuration file not found"
fi
echo

# 3. Whitelist
echo -e "${YELLOW}[3] Whitelist Status${NC}"
echo "-------------------"
whitelist_count=$(antiddos-cli whitelist list 2>/dev/null | grep -c "^\s*-")
if [ $whitelist_count -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Whitelist has $whitelist_count entries"
    echo "Current whitelisted IPs:"
    antiddos-cli whitelist list 2>/dev/null | grep "^\s*-"
else
    echo -e "${RED}✗${NC} WARNING: Whitelist is empty! You may lock yourself out."
fi
echo

# 4. Blacklist
echo -e "${YELLOW}[4] Blacklist Status${NC}"
echo "-------------------"
blacklist_count=$(antiddos-cli blacklist list 2>/dev/null | grep -c "^\s*-")
echo "Blacklisted IPs: $blacklist_count"
if [ $blacklist_count -gt 0 ]; then
    echo "Recent blocks (last 5):"
    antiddos-cli blacklist list 2>/dev/null | grep "^\s*-" | head -5
fi
echo

# 5. Firewall Rules
echo -e "${YELLOW}[5] Firewall Rules${NC}"
echo "-------------------"
if iptables -L ANTIDDOS -n &>/dev/null; then
    rule_count=$(iptables -L ANTIDDOS -n | grep -c "^")
    echo -e "${GREEN}✓${NC} ANTIDDOS chain exists with $rule_count rules"
    
    # Check if chain is being used
    if iptables -L INPUT -n | grep -q "ANTIDDOS"; then
        echo -e "${GREEN}✓${NC} ANTIDDOS chain is active in INPUT"
    else
        echo -e "${RED}✗${NC} ANTIDDOS chain not linked to INPUT"
    fi
else
    echo -e "${RED}✗${NC} ANTIDDOS chain not found"
fi
echo

# 6. Network Statistics
echo -e "${YELLOW}[6] Network Statistics${NC}"
echo "-------------------"
interface=$(grep "interface:" /etc/antiddos/config.yaml 2>/dev/null | awk '{print $2}')
if [ -n "$interface" ] && ip a show $interface &>/dev/null; then
    echo "Interface: $interface"
    
    # Get current traffic
    rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null)
    tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null)
    
    if [ -n "$rx_bytes" ] && [ -n "$tx_bytes" ]; then
        rx_mb=$((rx_bytes / 1024 / 1024))
        tx_mb=$((tx_bytes / 1024 / 1024))
        echo "Total RX: ${rx_mb} MB"
        echo "Total TX: ${tx_mb} MB"
    fi
    
    # Connection count
    conn_count=$(ss -tan | grep ESTAB | wc -l)
    echo "Active connections: $conn_count"
else
    echo -e "${RED}✗${NC} Cannot get network statistics"
fi
echo

# 7. Recent Logs
echo -e "${YELLOW}[7] Recent Log Entries${NC}"
echo "-------------------"
if [ -f /var/log/antiddos/antiddos.log ]; then
    echo "Last 5 log entries:"
    tail -5 /var/log/antiddos/antiddos.log
else
    echo -e "${RED}✗${NC} Log file not found"
fi
echo

# 8. System Resources
echo -e "${YELLOW}[8] System Resources${NC}"
echo "-------------------"
# CPU usage of services
for service in antiddos-monitor antiddos-ssh antiddos-xcord; do
    pid=$(systemctl show -p MainPID $service 2>/dev/null | cut -d= -f2)
    if [ "$pid" != "0" ] && [ -n "$pid" ]; then
        cpu=$(ps -p $pid -o %cpu= 2>/dev/null)
        mem=$(ps -p $pid -o %mem= 2>/dev/null)
        echo "$service: CPU ${cpu}%, MEM ${mem}%"
    fi
done
echo

# 9. Connectivity Test
echo -e "${YELLOW}[9] Connectivity Test${NC}"
echo "-------------------"
# Test if we can reach common services
if ping -c 1 8.8.8.8 &>/dev/null; then
    echo -e "${GREEN}✓${NC} Internet connectivity OK"
else
    echo -e "${RED}✗${NC} No internet connectivity"
fi

if [ -f /usr/share/GeoIP/GeoLite2-Country.mmdb ]; then
    echo -e "${GREEN}✓${NC} GeoIP database present"
else
    echo -e "${YELLOW}!${NC} GeoIP database not found (country filtering may not work)"
fi
echo

# 10. Recommendations
echo -e "${YELLOW}[10] Recommendations${NC}"
echo "-------------------"

recommendations=()

# Check if whitelist is empty
if [ $whitelist_count -eq 0 ]; then
    recommendations+=("Add your IP to whitelist: sudo antiddos-cli whitelist add YOUR_IP")
fi

# Check if default keys are in use
if grep -q "CHANGE_THIS" /etc/antiddos/config.yaml 2>/dev/null; then
    recommendations+=("Change default XCord keys in /etc/antiddos/config.yaml")
fi

# Check if services are running
for service in antiddos-monitor antiddos-ssh antiddos-xcord; do
    if ! systemctl is-active --quiet $service; then
        recommendations+=("Start $service: sudo systemctl start $service")
    fi
done

# Check if GeoIP database exists
if [ ! -f /usr/share/GeoIP/GeoLite2-Country.mmdb ]; then
    recommendations+=("Download GeoIP database: sudo antiddos-cli geoip update")
fi

if [ ${#recommendations[@]} -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No issues found!"
else
    for rec in "${recommendations[@]}"; do
        echo -e "${YELLOW}!${NC} $rec"
    done
fi
echo

# Summary
echo -e "${BLUE}=== Summary ===${NC}"
echo "Run this command to view real-time monitoring:"
echo "  sudo journalctl -u antiddos-monitor -f"
echo
echo "For more help, see:"
echo "  - /opt/anti-ddos/README.md"
echo "  - /opt/anti-ddos/LEEME.md (Spanish)"
echo "  - /opt/anti-ddos/docs/PTERODACTYL_DEPLOYMENT.md"
