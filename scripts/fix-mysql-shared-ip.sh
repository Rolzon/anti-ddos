#!/bin/bash

# Script para permitir múltiples servidores con la misma IP pública conectarse a MySQL
# Solución para servidores que comparten IP pública (NAT/Proxy)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# IP pública compartida
SHARED_PUBLIC_IP="190.57.138.18"

echo -e "${GREEN}=== Configurar MySQL para IP Pública Compartida ===${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
    exit 1
fi

# Detectar sistema de firewall
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

echo
echo -e "${YELLOW}Problema detectado:${NC}"
echo "Múltiples servidores comparten la IP pública: $SHARED_PUBLIC_IP"
echo "Las reglas actuales limitan conexiones por IP, bloqueando servidores legítimos."
echo

echo -e "${YELLOW}Solución:${NC}"
echo "1. Eliminar límites de conexión para la IP compartida"
echo "2. Permitir acceso ilimitado desde $SHARED_PUBLIC_IP"
echo "3. Mantener protecciones para otras IPs"
echo

read -p "¿Continuar? (s/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
    echo "Cancelado"
    exit 0
fi

echo
echo -e "${YELLOW}[1/3] Eliminando reglas restrictivas para $SHARED_PUBLIC_IP...${NC}"

# Eliminar reglas existentes que puedan bloquear la IP compartida
# Buscar y eliminar reglas de connlimit y rate limit para esta IP
$IPTABLES -L ANTIDDOS -n --line-numbers | grep "$SHARED_PUBLIC_IP" | grep -E "connlimit|limit" | tac | while read line; do
    line_num=$(echo $line | awk '{print $1}')
    if [[ $line_num =~ ^[0-9]+$ ]]; then
        $IPTABLES -D ANTIDDOS $line_num 2>/dev/null && echo "  ✓ Eliminada regla restrictiva #$line_num"
    fi
done

echo -e "${GREEN}✓ Reglas restrictivas eliminadas${NC}"

echo -e "${YELLOW}[2/3] Agregando regla de acceso ilimitado...${NC}"

# Agregar regla al inicio para permitir todo desde la IP compartida al puerto 3306
# Esta regla debe estar ANTES de cualquier límite
$IPTABLES -I ANTIDDOS 1 -s "$SHARED_PUBLIC_IP" -p tcp --dport 3306 -j ACCEPT

echo -e "${GREEN}✓ Regla de acceso ilimitado agregada (prioridad máxima)${NC}"

echo -e "${YELLOW}[3/3] Agregando IP a whitelist...${NC}"

# Agregar a whitelist si no está
if [ -f /etc/antiddos/whitelist.txt ]; then
    if ! grep -q "$SHARED_PUBLIC_IP" /etc/antiddos/whitelist.txt; then
        echo "$SHARED_PUBLIC_IP  # IP pública compartida - Servidores internos" >> /etc/antiddos/whitelist.txt
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
echo "La IP $SHARED_PUBLIC_IP ahora tiene:"
echo "  ✓ Acceso ilimitado al puerto 3306"
echo "  ✓ Sin límites de conexiones simultáneas"
echo "  ✓ Sin rate limiting"
echo "  ✓ Prioridad máxima (regla #1)"
echo

echo "Reglas actuales para $SHARED_PUBLIC_IP:"
$IPTABLES -L ANTIDDOS -n -v --line-numbers | grep "$SHARED_PUBLIC_IP"

echo
echo -e "${YELLOW}Verificación:${NC}"
echo "Todos los servidores con IP $SHARED_PUBLIC_IP pueden ahora conectarse a MySQL"
echo
echo "Probar conexión:"
echo "  mysql -h 190.57.138.18 -u usuario -p"
echo
echo "Ver conexiones activas:"
echo "  sudo ss -tnp | grep :3306"
echo
echo "Ver todas las reglas de MySQL:"
echo "  sudo $IPTABLES -L ANTIDDOS -n -v | grep 3306"
