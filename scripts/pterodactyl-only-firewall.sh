#!/bin/bash

# Script SIMPLE para configurar firewall SOLO para Pterodactyl
# Sin Anti-DDoS, sin complicaciones

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Configuración Simple de Firewall para Pterodactyl ===${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
    exit 1
fi

# Detectar iptables
if command -v iptables-legacy &> /dev/null && iptables-legacy -L -n &>/dev/null 2>&1; then
    IPTABLES="iptables-legacy"
else
    IPTABLES="iptables"
fi

echo -e "${BLUE}Usando: $IPTABLES${NC}"
echo

echo -e "${YELLOW}[1/5] Limpiando TODAS las reglas...${NC}"

# Limpiar TODO
$IPTABLES -F
$IPTABLES -X
$IPTABLES -t nat -F
$IPTABLES -t mangle -F

echo -e "${GREEN}✓ Reglas limpiadas${NC}"

echo
echo -e "${YELLOW}[2/5] Configurando política ACCEPT...${NC}"

$IPTABLES -P INPUT ACCEPT
$IPTABLES -P FORWARD ACCEPT
$IPTABLES -P OUTPUT ACCEPT

echo -e "${GREEN}✓ Política ACCEPT configurada (todo permitido por defecto)${NC}"

echo
echo -e "${YELLOW}[3/5] Aplicando reglas básicas...${NC}"

# Loopback - SIEMPRE primero
$IPTABLES -A INPUT -i lo -j ACCEPT
$IPTABLES -A OUTPUT -o lo -j ACCEPT
echo "  ✓ Loopback (127.0.0.1)"

# Conexiones establecidas - MUY IMPORTANTE
$IPTABLES -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
echo "  ✓ Conexiones establecidas"

# Docker - CRÍTICO para Pterodactyl
$IPTABLES -A INPUT -i docker0 -j ACCEPT
$IPTABLES -A OUTPUT -o docker0 -j ACCEPT
$IPTABLES -A FORWARD -i docker0 -o docker0 -j ACCEPT
$IPTABLES -A FORWARD -i docker0 ! -o docker0 -j ACCEPT
$IPTABLES -A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
echo "  ✓ Docker (todas las interfaces)"

# Permitir tráfico de redes privadas
$IPTABLES -A INPUT -s 172.16.0.0/12 -j ACCEPT
$IPTABLES -A INPUT -s 10.0.0.0/8 -j ACCEPT
$IPTABLES -A INPUT -s 192.168.0.0/16 -j ACCEPT
echo "  ✓ Redes privadas"

echo
echo -e "${YELLOW}[4/5] Abriendo puertos específicos...${NC}"

# SSH
$IPTABLES -A INPUT -p tcp --dport 22 -j ACCEPT
echo "  ✓ 22 (SSH)"

# HTTP/HTTPS
$IPTABLES -A INPUT -p tcp --dport 80 -j ACCEPT
$IPTABLES -A INPUT -p tcp --dport 443 -j ACCEPT
echo "  ✓ 80/443 (HTTP/HTTPS)"

# Wings
$IPTABLES -A INPUT -p tcp --dport 8080 -j ACCEPT
echo "  ✓ 8080 (Wings)"

# SFTP
$IPTABLES -A INPUT -p tcp --dport 2022 -j ACCEPT
echo "  ✓ 2022 (SFTP)"

# MySQL
$IPTABLES -A INPUT -p tcp --dport 3306 -j ACCEPT
echo "  ✓ 3306 (MySQL)"

# Minecraft Java
$IPTABLES -A INPUT -p tcp --dport 25565 -j ACCEPT
$IPTABLES -A INPUT -p udp --dport 25565 -j ACCEPT
echo "  ✓ 25565 (Minecraft Java TCP/UDP)"

# Minecraft Bedrock
$IPTABLES -A INPUT -p tcp --dport 19132 -j ACCEPT
$IPTABLES -A INPUT -p udp --dport 19132 -j ACCEPT
echo "  ✓ 19132 (Minecraft Bedrock TCP/UDP)"

# Rango Pterodactyl
$IPTABLES -A INPUT -p tcp --dport 19133:20100 -j ACCEPT
$IPTABLES -A INPUT -p udp --dport 19133:20100 -j ACCEPT
echo "  ✓ 19133-20100 (Pterodactyl TCP/UDP)"

echo
echo -e "${YELLOW}[5/5] Guardando configuración...${NC}"

# Guardar reglas
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save &>/dev/null
    echo -e "${GREEN}✓ Guardado con netfilter-persistent${NC}"
elif command -v iptables-save &> /dev/null; then
    if [ ! -d /etc/iptables ]; then
        mkdir -p /etc/iptables
    fi
    $IPTABLES-save > /etc/iptables/rules.v4
    echo -e "${GREEN}✓ Guardado en /etc/iptables/rules.v4${NC}"
else
    echo -e "${YELLOW}! No se pudo guardar permanentemente${NC}"
    echo "  Instalar: apt-get install iptables-persistent"
fi

echo
echo -e "${GREEN}=== Configuración Completada ===${NC}"
echo

echo -e "${BLUE}Resumen:${NC}"
echo "  Política: ACCEPT (todo permitido por defecto)"
echo "  Reglas aplicadas: $(($IPTABLES -L INPUT -n | wc -l) - 2)"
echo

echo -e "${BLUE}Puertos abiertos:${NC}"
echo "  ✓ 22 (SSH)"
echo "  ✓ 80, 443 (HTTP/HTTPS)"
echo "  ✓ 8080 (Wings)"
echo "  ✓ 2022 (SFTP)"
echo "  ✓ 3306 (MySQL)"
echo "  ✓ 25565 (Minecraft Java)"
echo "  ✓ 19132 (Minecraft Bedrock)"
echo "  ✓ 19133-20100 (Pterodactyl)"
echo

echo -e "${YELLOW}Reiniciando servicios...${NC}"
systemctl restart docker 2>/dev/null && echo "  ✓ Docker reiniciado"
systemctl restart wings 2>/dev/null && echo "  ✓ Wings reiniciado"

echo
echo -e "${BLUE}Verificación:${NC}"
echo

echo "Reglas actuales:"
$IPTABLES -L INPUT -n --line-numbers

echo
echo "Puertos escuchando:"
ss -tulnp | grep -E "8080|2022|25565|19132" | head -10

echo
echo -e "${GREEN}✓ Firewall configurado correctamente${NC}"
echo -e "${GREEN}✓ Todos los puertos de Pterodactyl están abiertos${NC}"
echo
echo "Probar desde fuera:"
echo "  nc -zv 190.57.138.18 25565"
echo "  nc -zv 190.57.138.18 19132"
