#!/bin/bash

# Script para abrir todos los puertos necesarios de Pterodactyl
# Incluye rangos de puertos para servidores de juegos

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Configuración de Puertos Pterodactyl ===${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
    exit 1
fi

# Detectar sistema de firewall
echo -e "${YELLOW}[1/5] Detectando sistema de firewall...${NC}"
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

# Verificar si la cadena ANTIDDOS existe
echo
echo -e "${YELLOW}[2/5] Verificando cadena ANTIDDOS...${NC}"
if $IPTABLES -L ANTIDDOS -n &>/dev/null; then
    echo -e "${GREEN}✓ Cadena ANTIDDOS encontrada${NC}"
    HAS_ANTIDDOS=true
else
    echo -e "${YELLOW}! Cadena ANTIDDOS no existe${NC}"
    HAS_ANTIDDOS=false
fi

# Definir puertos y rangos
echo
echo -e "${YELLOW}[3/5] Configurando puertos de Pterodactyl...${NC}"

# Puertos individuales
SINGLE_PORTS=(
    "25565"  # Minecraft Java
    "19132"  # Minecraft Bedrock
)

# Rangos de puertos
PORT_RANGES=(
    "19133:20100"  # Rango principal de servidores
)

echo "Puertos a abrir:"
echo "  - Individuales: ${SINGLE_PORTS[@]}"
echo "  - Rangos: ${PORT_RANGES[@]}"
echo

# Abrir puertos individuales
echo -e "${YELLOW}[4/5] Abriendo puertos individuales...${NC}"

for port in "${SINGLE_PORTS[@]}"; do
    # TCP
    if [ "$HAS_ANTIDDOS" = true ]; then
        $IPTABLES -I ANTIDDOS 1 -p tcp --dport "$port" -j ACCEPT
    fi
    $IPTABLES -I INPUT 1 -p tcp --dport "$port" -j ACCEPT
    
    # UDP
    if [ "$HAS_ANTIDDOS" = true ]; then
        $IPTABLES -I ANTIDDOS 1 -p udp --dport "$port" -j ACCEPT
    fi
    $IPTABLES -I INPUT 1 -p udp --dport "$port" -j ACCEPT
    
    echo "  ✓ Puerto $port (TCP/UDP) abierto"
done

# Abrir rangos de puertos
echo
echo -e "${YELLOW}[5/5] Abriendo rangos de puertos...${NC}"

for range in "${PORT_RANGES[@]}"; do
    # TCP
    if [ "$HAS_ANTIDDOS" = true ]; then
        $IPTABLES -I ANTIDDOS 1 -p tcp --dport "$range" -j ACCEPT
    fi
    $IPTABLES -I INPUT 1 -p tcp --dport "$range" -j ACCEPT
    
    # UDP
    if [ "$HAS_ANTIDDOS" = true ]; then
        $IPTABLES -I ANTIDDOS 1 -p udp --dport "$range" -j ACCEPT
    fi
    $IPTABLES -I INPUT 1 -p udp --dport "$range" -j ACCEPT
    
    echo "  ✓ Rango $range (TCP/UDP) abierto"
done

# Guardar reglas
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save &>/dev/null
    echo -e "${GREEN}✓ Reglas guardadas permanentemente${NC}"
fi

echo
echo -e "${GREEN}=== Configuración Completada ===${NC}"
echo
echo -e "${BLUE}Puertos abiertos:${NC}"
echo "  ✓ 25565 (TCP/UDP) - Minecraft Java"
echo "  ✓ 19132 (TCP/UDP) - Minecraft Bedrock"
echo "  ✓ 19133-20100 (TCP/UDP) - Servidores Pterodactyl"
echo

echo -e "${YELLOW}Verificación:${NC}"
echo "Ver reglas aplicadas:"
echo "  sudo $IPTABLES -L -n -v | grep -E '25565|19132|19133:20100'"
echo
echo "Probar conexión a un servidor:"
echo "  nc -zv IP_DEL_SERVIDOR PUERTO"
echo
echo "Ver puertos escuchando:"
echo "  sudo ss -tulnp | grep -E '25565|19132|19133'"
echo

echo -e "${GREEN}✓ Los servidores de Pterodactyl deberían ser accesibles ahora${NC}"
