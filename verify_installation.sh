#!/bin/bash

echo "================================================"
echo "  Anti-DDoS - Verificación de Instalación"
echo "================================================"
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

# Función para verificar
check() {
    if eval "$1" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $2"
        return 0
    else
        echo -e "${RED}✗${NC} $2"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

echo "=== VERIFICACIÓN DEL SISTEMA ==="
check "command -v python3" "Python3 instalado"
check "command -v pip3" "pip3 instalado"
check "command -v iptables" "iptables instalado"
check "command -v docker" "Docker instalado"
check "[[ -x /usr/sbin/iptables-nft ]]" "iptables-nft disponible"
echo ""

echo "=== VERIFICACIÓN DEL PROYECTO ==="
check "command -v antiddos" "Comando antiddos disponible"
check "python3 -c 'import antiddos'" "Módulo Python antiddos importable"
echo ""

echo "=== VERIFICACIÓN DE ARCHIVOS ==="
check "[[ -f /etc/antiddos/config.yaml ]]" "Configuración existe"
check "[[ -r /etc/antiddos/config.yaml ]]" "Configuración es legible"
check "[[ -f /etc/antiddos/blacklist.txt ]]" "Blacklist existe"
check "[[ -f /etc/antiddos/whitelist.txt ]]" "Whitelist existe"
check "[[ -d /var/log/antiddos ]]" "Directorio de logs existe"
check "[[ -w /var/log/antiddos ]]" "Directorio de logs escribible"
echo ""

echo "=== VERIFICACIÓN DE SYSTEMD ==="
check "[[ -f /etc/systemd/system/antiddos-monitor.service ]]" "Archivo de servicio existe"
check "systemctl list-unit-files | grep -q antiddos-monitor" "Servicio registrado en systemd"

if systemctl is-active --quiet antiddos-monitor; then
    echo -e "${GREEN}✓${NC} Servicio está corriendo"
    
    # Verificar logs recientes
    if journalctl -u antiddos-monitor -n 10 --no-pager 2>/dev/null | grep -q "Anti-DDoS Monitor"; then
        echo -e "${GREEN}✓${NC} Logs del servicio accesibles"
    else
        echo -e "${YELLOW}⚠${NC} No se encontraron logs recientes"
    fi
else
    echo -e "${YELLOW}⚠${NC} Servicio no está corriendo (normal si no se ha iniciado aún)"
fi
echo ""

echo "=== VERIFICACIÓN DE IPTABLES ==="
if [[ $EUID -eq 0 ]]; then
    # Solo verificar reglas si somos root
    if iptables -L ANTIDDOS -n &>/dev/null; then
        echo -e "${GREEN}✓${NC} Cadena ANTIDDOS existe"
        
        if iptables -L INPUT -n | grep -q ANTIDDOS; then
            echo -e "${GREEN}✓${NC} ANTIDDOS vinculada a INPUT"
        else
            echo -e "${RED}✗${NC} ANTIDDOS NO vinculada a INPUT"
            ERRORS=$((ERRORS + 1))
        fi
        
        if iptables -L FORWARD -n | grep -q ANTIDDOS; then
            echo -e "${GREEN}✓${NC} ANTIDDOS vinculada a FORWARD (Docker)"
        else
            echo -e "${YELLOW}⚠${NC} ANTIDDOS NO vinculada a FORWARD (necesario para Docker)"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Cadena ANTIDDOS no existe (normal si no se ha iniciado)"
    fi
else
    echo -e "${YELLOW}⚠${NC} Requiere root para verificar reglas iptables"
    echo "    Ejecuta: sudo $0"
fi
echo ""

echo "=== VERIFICACIÓN DE PERMISOS ==="
if [[ $EUID -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} Script ejecutado como root"
else
    echo -e "${YELLOW}⚠${NC} Script NO ejecutado como root"
    echo "    Algunas verificaciones requieren sudo"
fi
echo ""

# RESUMEN
echo "================================================"
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ TODAS LAS VERIFICACIONES PASARON${NC}"
    echo ""
    echo "El sistema está listo. Puedes:"
    echo "  1. Verificar configuración: cat /etc/antiddos/config.yaml"
    echo "  2. Iniciar servicio:        sudo systemctl start antiddos-monitor"
    echo "  3. Ver logs en tiempo real: sudo journalctl -u antiddos-monitor -f"
    echo "  4. Ver estado:              antiddos status"
else
    echo -e "${RED}✗ SE ENCONTRARON $ERRORS ERROR(ES)${NC}"
    echo ""
    echo "Soluciones:"
    echo "  - Si falta instalación: sudo ./reinstall.sh"
    echo "  - Si faltan permisos:   Ejecuta con sudo"
    echo "  - Si falla servicio:    sudo journalctl -u antiddos-monitor -n 50"
fi
echo "================================================"
echo ""
