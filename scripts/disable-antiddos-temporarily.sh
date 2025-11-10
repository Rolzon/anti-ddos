#!/bin/bash

# Script para desactivar temporalmente ANTIDDOS y abrir todos los puertos
# Útil para diagnosticar si ANTIDDOS es el problema

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}=== Desactivación Temporal de ANTIDDOS ===${NC}"
echo -e "${YELLOW}⚠ ADVERTENCIA: Esto desactivará la protección DDoS temporalmente${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
    exit 1
fi

read -p "¿Estás seguro de continuar? (s/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
    echo "Cancelado"
    exit 0
fi

# Detectar iptables
if command -v iptables-legacy &> /dev/null && iptables-legacy -L -n &>/dev/null 2>&1; then
    IPTABLES="iptables-legacy"
else
    IPTABLES="iptables"
fi

echo
echo -e "${YELLOW}[1/6] Deteniendo servicios Anti-DDoS...${NC}"
systemctl stop antiddos-monitor 2>/dev/null
systemctl stop antiddos-ssh 2>/dev/null
echo -e "${GREEN}✓ Servicios detenidos${NC}"

echo
echo -e "${YELLOW}[2/6] Removiendo cadena ANTIDDOS...${NC}"

# Remover saltos a ANTIDDOS
while $IPTABLES -D INPUT -j ANTIDDOS 2>/dev/null; do
    echo "  Removido salto de INPUT"
done

while $IPTABLES -D FORWARD -j ANTIDDOS 2>/dev/null; do
    echo "  Removido salto de FORWARD"
done

# Limpiar y eliminar cadena
if $IPTABLES -L ANTIDDOS -n &>/dev/null; then
    $IPTABLES -F ANTIDDOS
    $IPTABLES -X ANTIDDOS
    echo -e "${GREEN}✓ Cadena ANTIDDOS eliminada${NC}"
fi

echo
echo -e "${YELLOW}[3/6] Limpiando todas las reglas...${NC}"
$IPTABLES -F INPUT
$IPTABLES -F FORWARD
$IPTABLES -F OUTPUT
echo -e "${GREEN}✓ Reglas limpiadas${NC}"

echo
echo -e "${YELLOW}[4/6] Configurando política ACCEPT...${NC}"
$IPTABLES -P INPUT ACCEPT
$IPTABLES -P FORWARD ACCEPT
$IPTABLES -P OUTPUT ACCEPT
echo -e "${GREEN}✓ Política ACCEPT configurada${NC}"

echo
echo -e "${YELLOW}[5/6] Aplicando reglas mínimas...${NC}"

# Loopback
$IPTABLES -A INPUT -i lo -j ACCEPT
echo "  ✓ Loopback"

# Conexiones establecidas
$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
echo "  ✓ Conexiones establecidas"

# Docker
$IPTABLES -A INPUT -i docker0 -j ACCEPT
$IPTABLES -A FORWARD -i docker0 -j ACCEPT
$IPTABLES -A FORWARD -o docker0 -j ACCEPT
echo "  ✓ Docker"

# Todos los puertos comunes
$IPTABLES -A INPUT -p tcp --dport 22 -j ACCEPT
$IPTABLES -A INPUT -p tcp --dport 80 -j ACCEPT
$IPTABLES -A INPUT -p tcp --dport 443 -j ACCEPT
$IPTABLES -A INPUT -p tcp --dport 8080 -j ACCEPT
$IPTABLES -A INPUT -p tcp --dport 2022 -j ACCEPT
$IPTABLES -A INPUT -p tcp --dport 3306 -j ACCEPT
$IPTABLES -A INPUT -p tcp --dport 25565 -j ACCEPT
$IPTABLES -A INPUT -p udp --dport 25565 -j ACCEPT
$IPTABLES -A INPUT -p tcp --dport 19132 -j ACCEPT
$IPTABLES -A INPUT -p udp --dport 19132 -j ACCEPT
$IPTABLES -A INPUT -p tcp --dport 19133:20100 -j ACCEPT
$IPTABLES -A INPUT -p udp --dport 19133:20100 -j ACCEPT
echo "  ✓ Todos los puertos abiertos"

echo
echo -e "${GREEN}✓ Reglas mínimas aplicadas${NC}"

echo
echo -e "${YELLOW}[6/6] Guardando configuración...${NC}"
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save &>/dev/null
    echo -e "${GREEN}✓ Guardado${NC}"
fi

echo
echo -e "${GREEN}=== ANTIDDOS Desactivado ===${NC}"
echo
echo -e "${BLUE}Estado actual:${NC}"
echo "  ✓ Política: ACCEPT (todo permitido)"
echo "  ✓ Cadena ANTIDDOS: ELIMINADA"
echo "  ✓ Servicios Anti-DDoS: DETENIDOS"
echo "  ✓ Todos los puertos: ABIERTOS"
echo
echo -e "${YELLOW}Reglas actuales:${NC}"
$IPTABLES -L INPUT -n --line-numbers | head -20

echo
echo -e "${BLUE}Verificación:${NC}"
echo "Probar puertos:"
echo "  nc -zv 190.57.138.18 25565"
echo "  nc -zv 190.57.138.18 19132"
echo
echo "Ver puertos escuchando:"
echo "  sudo ss -tulnp | grep -E '25565|19132'"
echo
echo -e "${RED}⚠ IMPORTANTE:${NC}"
echo "Para REACTIVAR la protección DDoS:"
echo "  sudo systemctl start antiddos-monitor"
echo "  sudo systemctl start antiddos-ssh"
echo
echo -e "${GREEN}✓ Ahora prueba conectar a los servidores${NC}"
