#!/bin/bash

# Script para permitir tráfico de Pterodactyl y Docker
# Soluciona el error: "iptables failed: iptables --wait -t nat -A DOCKER"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Configuración Pterodactyl + Docker ===${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
    exit 1
fi

# Detectar sistema de firewall
echo -e "${YELLOW}[1/6] Detectando sistema de firewall...${NC}"
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
echo -e "${YELLOW}[2/6] Verificando cadena ANTIDDOS...${NC}"
if $IPTABLES -L ANTIDDOS -n &>/dev/null; then
    echo -e "${GREEN}✓ Cadena ANTIDDOS encontrada${NC}"
    HAS_ANTIDDOS=true
else
    echo -e "${YELLOW}! Cadena ANTIDDOS no existe${NC}"
    HAS_ANTIDDOS=false
fi

# Permitir interfaz docker0
echo
echo -e "${YELLOW}[3/6] Permitiendo interfaz Docker (docker0)...${NC}"

if [ "$HAS_ANTIDDOS" = true ]; then
    # Permitir TODO el tráfico de docker0
    $IPTABLES -I ANTIDDOS 1 -i docker0 -j ACCEPT
    $IPTABLES -I ANTIDDOS 1 -o docker0 -j ACCEPT
    echo -e "${GREEN}✓ Interfaz docker0 permitida en ANTIDDOS${NC}"
fi

# También en INPUT/OUTPUT/FORWARD
$IPTABLES -I INPUT 1 -i docker0 -j ACCEPT
$IPTABLES -I OUTPUT 1 -o docker0 -j ACCEPT
$IPTABLES -I FORWARD 1 -i docker0 -j ACCEPT
$IPTABLES -I FORWARD 1 -o docker0 -j ACCEPT

echo -e "${GREEN}✓ Interfaz docker0 permitida globalmente${NC}"

# Permitir redes internas de Docker
echo
echo -e "${YELLOW}[4/6] Permitiendo redes internas de Docker...${NC}"

DOCKER_NETWORKS=(
    "172.16.0.0/12"
    "172.17.0.0/16"
    "172.18.0.0/16"
    "10.0.0.0/8"
    "192.168.0.0/16"
)

for network in "${DOCKER_NETWORKS[@]}"; do
    if [ "$HAS_ANTIDDOS" = true ]; then
        $IPTABLES -I ANTIDDOS 1 -s "$network" -j ACCEPT
        $IPTABLES -I ANTIDDOS 1 -d "$network" -j ACCEPT
    fi
    $IPTABLES -I INPUT 1 -s "$network" -j ACCEPT
    $IPTABLES -I OUTPUT 1 -d "$network" -j ACCEPT
    echo "  ✓ Red $network permitida"
done

echo -e "${GREEN}✓ Redes internas de Docker permitidas${NC}"

# Permitir comunicación Pterodactyl Wings
echo
echo -e "${YELLOW}[5/6] Permitiendo puertos de Pterodactyl...${NC}"

# Puerto Wings (8080)
if [ "$HAS_ANTIDDOS" = true ]; then
    $IPTABLES -I ANTIDDOS 1 -p tcp --dport 8080 -j ACCEPT
    $IPTABLES -I ANTIDDOS 1 -p tcp --sport 8080 -j ACCEPT
fi
$IPTABLES -I INPUT 1 -p tcp --dport 8080 -j ACCEPT
echo "  ✓ Puerto 8080 (Wings) permitido"

# Puerto SFTP (2022)
if [ "$HAS_ANTIDDOS" = true ]; then
    $IPTABLES -I ANTIDDOS 1 -p tcp --dport 2022 -j ACCEPT
fi
$IPTABLES -I INPUT 1 -p tcp --dport 2022 -j ACCEPT
echo "  ✓ Puerto 2022 (SFTP) permitido"

# Rango de puertos de servidores (25565-25665 para Minecraft, etc)
if [ "$HAS_ANTIDDOS" = true ]; then
    $IPTABLES -I ANTIDDOS 1 -p tcp --dport 25565:25665 -j ACCEPT
    $IPTABLES -I ANTIDDOS 1 -p udp --dport 25565:25665 -j ACCEPT
fi
$IPTABLES -I INPUT 1 -p tcp --dport 25565:25665 -j ACCEPT
$IPTABLES -I INPUT 1 -p udp --dport 25565:25665 -j ACCEPT
echo "  ✓ Puertos 25565-25665 (Servidores) permitidos"

echo -e "${GREEN}✓ Puertos de Pterodactyl permitidos${NC}"

# Permitir localhost
echo
echo -e "${YELLOW}[6/6] Asegurando comunicación localhost...${NC}"

if [ "$HAS_ANTIDDOS" = true ]; then
    $IPTABLES -I ANTIDDOS 1 -i lo -j ACCEPT
    $IPTABLES -I ANTIDDOS 1 -s 127.0.0.0/8 -j ACCEPT
fi
$IPTABLES -I INPUT 1 -i lo -j ACCEPT
$IPTABLES -I OUTPUT 1 -o lo -j ACCEPT

echo -e "${GREEN}✓ Localhost permitido${NC}"

# Guardar reglas
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save &>/dev/null
    echo -e "${GREEN}✓ Reglas guardadas permanentemente${NC}"
fi

echo
echo -e "${GREEN}=== Configuración Completada ===${NC}"
echo
echo -e "${BLUE}Reglas aplicadas:${NC}"
echo "  ✓ Interfaz docker0: PERMITIDA"
echo "  ✓ Redes Docker: PERMITIDAS"
echo "  ✓ Puerto 8080 (Wings): PERMITIDO"
echo "  ✓ Puerto 2022 (SFTP): PERMITIDO"
echo "  ✓ Puertos 25565-25665: PERMITIDOS"
echo "  ✓ Localhost: PERMITIDO"
echo

echo -e "${YELLOW}Ahora intenta:${NC}"
echo "1. Reiniciar Docker:"
echo "   sudo systemctl restart docker"
echo
echo "2. Reiniciar Wings:"
echo "   sudo systemctl restart wings"
echo
echo "3. Iniciar un servidor en Pterodactyl"
echo
echo "4. Ver logs de Wings:"
echo "   sudo journalctl -u wings -f"
echo
echo -e "${GREEN}✓ Pterodactyl debería funcionar ahora${NC}"
