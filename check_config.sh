#!/bin/bash

# Script para verificar que la configuración corregida está aplicada

echo "================================================"
echo "  Verificación de Configuración Anti-DDoS"
echo "================================================"
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CONFIG_FILE="/etc/antiddos/config.yaml"
ERRORS=0

check() {
    local test="$1"
    local expected="$2"
    local actual="$3"
    
    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}✓${NC} $test: $actual"
        return 0
    else
        echo -e "${RED}✗${NC} $test: $actual (esperado: $expected)"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

echo "=== VERIFICANDO UMBRALES CRÍTICOS ==="

# Verificar min_connections
MIN_CONN=$(grep -A 3 "auto_blacklist:" "$CONFIG_FILE" | grep "min_connections:" | awk '{print $2}' | head -1)
check "min_connections" "10" "$MIN_CONN"

# Verificar min_pps
MIN_PPS=$(grep -A 3 "auto_udp_block:" "$CONFIG_FILE" | grep "min_pps:" | awk '{print $2}' | head -1)
check "min_pps" "800" "$MIN_PPS"

# Verificar ban_connection_threshold
BAN_THRESH=$(grep "ban_connection_threshold:" "$CONFIG_FILE" | awk '{print $2}' | head -1)
check "ban_connection_threshold" "5" "$BAN_THRESH"

# Verificar ban_duration_seconds
BAN_DUR=$(grep "ban_duration_seconds:" "$CONFIG_FILE" | awk '{print $2}' | head -1)
check "ban_duration_seconds" "3600" "$BAN_DUR"

# Verificar default_threshold_pps
DEFAULT_PPS=$(grep "default_threshold_pps:" "$CONFIG_FILE" | awk '{print $2}' | head -1)
check "default_threshold_pps" "500" "$DEFAULT_PPS"

echo ""
echo "=== VERIFICANDO SERVICIOS ==="

if systemctl is-active --quiet antiddos-monitor; then
    echo -e "${GREEN}✓${NC} Servicio antiddos-monitor está corriendo"
else
    echo -e "${RED}✗${NC} Servicio antiddos-monitor NO está corriendo"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "=== VERIFICANDO REGLAS IPTABLES ==="

if [[ $EUID -eq 0 ]]; then
    # Verificar cadena ANTIDDOS existe
    if iptables -L ANTIDDOS -n &>/dev/null; then
        echo -e "${GREEN}✓${NC} Cadena ANTIDDOS existe"
        
        # Verificar en FORWARD (Docker)
        if iptables -L FORWARD -n | grep -q ANTIDDOS; then
            echo -e "${GREEN}✓${NC} ANTIDDOS vinculada a FORWARD (Docker)"
        else
            echo -e "${RED}✗${NC} ANTIDDOS NO vinculada a FORWARD (Docker no protegido)"
            ERRORS=$((ERRORS + 1))
        fi
        
        # Verificar en INPUT
        if iptables -L INPUT -n | grep -q ANTIDDOS; then
            echo -e "${GREEN}✓${NC} ANTIDDOS vinculada a INPUT"
        else
            echo -e "${YELLOW}⚠${NC} ANTIDDOS NO vinculada a INPUT"
        fi
        
        # Contar IPs bloqueadas
        BLOCKED_COUNT=$(iptables -L ANTIDDOS -n | grep -c "DROP.*all.*0.0.0.0/0")
        if [[ $BLOCKED_COUNT -gt 0 ]]; then
            echo -e "${GREEN}✓${NC} IPs bloqueadas actualmente: $BLOCKED_COUNT"
        else
            echo -e "${YELLOW}⚠${NC} No hay IPs bloqueadas actualmente (normal si no hay ataques)"
        fi
    else
        echo -e "${RED}✗${NC} Cadena ANTIDDOS no existe (servicio no ha inicializado)"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${YELLOW}⚠${NC} Requiere root para verificar iptables"
    echo "    Ejecuta: sudo $0"
fi

echo ""
echo "=== ÚLTIMOS LOGS (5 líneas) ==="
if [[ $EUID -eq 0 ]]; then
    journalctl -u antiddos-monitor -n 5 --no-pager 2>/dev/null || echo "No se pueden leer logs"
else
    echo "Ejecuta 'sudo journalctl -u antiddos-monitor -n 20' para ver logs"
fi

echo ""
echo "================================================"
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ CONFIGURACIÓN CORRECTA${NC}"
    echo ""
    echo "El sistema está configurado con los umbrales corregidos."
    echo "Las IPs atacantes DEBERÍAN bloquearse automáticamente."
    echo ""
    echo "Monitorear logs: sudo journalctl -u antiddos-monitor -f"
else
    echo -e "${RED}✗ SE ENCONTRARON $ERRORS ERROR(ES)${NC}"
    echo ""
    echo "Soluciones:"
    echo "  1. Si umbrales incorrectos: sudo nano /etc/antiddos/config.yaml"
    echo "  2. Si servicio no corre:    sudo systemctl restart antiddos-monitor"
    echo "  3. Si faltan reglas:        sudo systemctl restart antiddos-monitor"
    echo "  4. Ver logs de error:       sudo journalctl -u antiddos-monitor -n 50"
fi
echo "================================================"
