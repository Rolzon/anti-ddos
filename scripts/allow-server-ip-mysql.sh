#!/bin/bash

# Script para permitir la IP pública del servidor en el puerto MySQL
# Útil cuando el servidor necesita conectarse a sí mismo usando su IP pública

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# IP pública del servidor
SERVER_PUBLIC_IP="190.57.138.18"

echo -e "${GREEN}=== Permitir IP Pública del Servidor en MySQL ===${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
    exit 1
fi

# Detectar si usa iptables-legacy o iptables-nft
echo -e "${YELLOW}Detectando sistema de firewall...${NC}"
if command -v iptables-legacy &> /dev/null; then
    if iptables-legacy -L -n &>/dev/null 2>&1; then
        IPTABLES="iptables-legacy"
        echo -e "${GREEN}✓ Usando iptables-legacy${NC}"
    else
        IPTABLES="iptables"
        echo -e "${GREEN}✓ Usando iptables${NC}"
    fi
else
    IPTABLES="iptables"
    echo -e "${GREEN}✓ Usando iptables${NC}"
fi

# Verificar que la cadena ANTIDDOS existe
if ! $IPTABLES -L ANTIDDOS -n &>/dev/null; then
    echo -e "${RED}Error: La cadena ANTIDDOS no existe${NC}"
    echo "Ejecuta primero: sudo systemctl start antiddos-monitor"
    exit 1
fi

echo -e "${YELLOW}Configurando acceso desde IP pública del servidor...${NC}"
echo "IP: $SERVER_PUBLIC_IP"
echo

# Permitir conexiones desde la IP pública del servidor al puerto 3306
$IPTABLES -I ANTIDDOS -s "$SERVER_PUBLIC_IP" -p tcp --dport 3306 -j ACCEPT

echo -e "${GREEN}✓ Regla agregada${NC}"

# También agregar a whitelist si no está
if [ -f /etc/antiddos/whitelist.txt ]; then
    if ! grep -q "$SERVER_PUBLIC_IP" /etc/antiddos/whitelist.txt; then
        echo "$SERVER_PUBLIC_IP  # IP pública del servidor" >> /etc/antiddos/whitelist.txt
        echo -e "${GREEN}✓ IP agregada a whitelist${NC}"
    else
        echo -e "${YELLOW}! IP ya está en whitelist${NC}"
    fi
fi

# Guardar reglas
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save
    echo -e "${GREEN}✓ Reglas guardadas${NC}"
fi

echo
echo -e "${GREEN}=== Configuración Completada ===${NC}"
echo
echo "La IP $SERVER_PUBLIC_IP ahora puede conectarse al puerto 3306"
echo
echo "Verificar regla:"
echo "  sudo $IPTABLES -L ANTIDDOS -n -v | grep $SERVER_PUBLIC_IP"
echo
echo "Probar conexión:"
echo "  mysql -h $SERVER_PUBLIC_IP -u usuario -p"
