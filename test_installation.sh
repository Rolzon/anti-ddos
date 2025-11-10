#!/bin/bash

# Anti-DDoS Installation Test Script

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Anti-DDoS Installation Test ===${NC}"
echo

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $1"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $1"
        ((TESTS_FAILED++))
    fi
}

# 1. Check if running as root
echo -e "${YELLOW}[1] Checking root privileges...${NC}"
if [ "$EUID" -eq 0 ]; then
    test_check "Running as root"
else
    echo -e "${RED}✗ FAIL${NC}: Not running as root"
    ((TESTS_FAILED++))
fi

# 2. Check Python version
echo -e "${YELLOW}[2] Checking Python version...${NC}"
python3 --version | grep -q "3.1[0-9]"
test_check "Python 3.10+ installed"

# 3. Check if configuration exists
echo -e "${YELLOW}[3] Checking configuration...${NC}"
[ -f /etc/antiddos/config.yaml ]
test_check "Configuration file exists"

# 4. Check if directories exist
echo -e "${YELLOW}[4] Checking directories...${NC}"
[ -d /var/log/antiddos ]
test_check "Log directory exists"

# 5. Check if Python package is installed
echo -e "${YELLOW}[5] Checking Python package...${NC}"
python3 -c "import antiddos" 2>/dev/null
test_check "Anti-DDoS package installed"

# 6. Check if CLI is available
echo -e "${YELLOW}[6] Checking CLI...${NC}"
which antiddos-cli >/dev/null 2>&1
test_check "CLI command available"

# 7. Check systemd services
echo -e "${YELLOW}[7] Checking systemd services...${NC}"
[ -f /etc/systemd/system/antiddos-monitor.service ]
test_check "Monitor service file exists"

[ -f /etc/systemd/system/antiddos-ssh.service ]
test_check "SSH protection service file exists"

[ -f /etc/systemd/system/antiddos-xcord.service ]
test_check "XCord service file exists"

# 8. Check iptables
echo -e "${YELLOW}[8] Checking iptables...${NC}"
which iptables >/dev/null 2>&1
test_check "iptables installed"

# 9. Check Python dependencies
echo -e "${YELLOW}[9] Checking Python dependencies...${NC}"
python3 -c "import yaml" 2>/dev/null
test_check "PyYAML installed"

python3 -c "import psutil" 2>/dev/null
test_check "psutil installed"

python3 -c "from cryptography.fernet import Fernet" 2>/dev/null
test_check "cryptography installed"

# 10. Test CLI commands
echo -e "${YELLOW}[10] Testing CLI commands...${NC}"
antiddos-cli stats >/dev/null 2>&1
test_check "CLI stats command works"

# 11. Check if services are loaded
echo -e "${YELLOW}[11] Checking service status...${NC}"
systemctl list-unit-files | grep -q antiddos-monitor
test_check "Monitor service loaded"

systemctl list-unit-files | grep -q antiddos-ssh
test_check "SSH protection service loaded"

systemctl list-unit-files | grep -q antiddos-xcord
test_check "XCord service loaded"

# 12. Check configuration validity
echo -e "${YELLOW}[12] Validating configuration...${NC}"
python3 -c "import yaml; yaml.safe_load(open('/etc/antiddos/config.yaml'))" 2>/dev/null
test_check "Configuration file is valid YAML"

# 13. Check file permissions
echo -e "${YELLOW}[13] Checking file permissions...${NC}"
[ -r /etc/antiddos/config.yaml ]
test_check "Configuration file is readable"

[ -w /var/log/antiddos ]
test_check "Log directory is writable"

# Summary
echo
echo -e "${GREEN}=== Test Summary ===${NC}"
echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"
echo

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! Installation appears to be successful.${NC}"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Edit /etc/antiddos/config.yaml"
    echo "2. Add your IP to whitelist: sudo antiddos-cli whitelist add YOUR_IP"
    echo "3. Start services: sudo systemctl start antiddos-monitor antiddos-ssh antiddos-xcord"
    echo "4. Check status: sudo systemctl status antiddos-monitor"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review the output above.${NC}"
    exit 1
fi
