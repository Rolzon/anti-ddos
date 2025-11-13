#!/bin/bash

# Script de prueba para verificar que las protecciones funcionan
# Este script NO modifica nada, solo verifica

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     VERIFICACIÓN DE PROTECCIONES DOCKER/WINGS     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo

# 1. Verificar que las cadenas DOCKER existen y están intactas
echo -e "${YELLOW}[1/6] Verificando cadenas DOCKER...${NC}"
if iptables -t nat -L DOCKER -n &>/dev/null; then
    echo -e "${GREEN}✓ Cadena DOCKER existe en tabla NAT${NC}"
    DOCKER_RULES=$(iptables -t nat -L DOCKER -n | wc -l)
    echo -e "${GREEN}  Reglas en DOCKER: $DOCKER_RULES${NC}"
else
    echo -e "${RED}✗ Cadena DOCKER no encontrada${NC}"
fi

if iptables -L DOCKER-ISOLATION-STAGE-1 -n &>/dev/null; then
    echo -e "${GREEN}✓ Cadena DOCKER-ISOLATION-STAGE-1 existe${NC}"
else
    echo -e "${YELLOW}! Cadena DOCKER-ISOLATION-STAGE-1 no encontrada${NC}"
fi

# 2. Verificar subnet 172.18.0.0/16
echo
echo -e "${YELLOW}[2/6] Verificando protección de subnet 172.18.0.0/16...${NC}"
if iptables -L INPUT -n | grep -q "172.18.0.0/16"; then
    echo -e "${GREEN}✓ Subnet 172.18.0.0/16 está protegida en INPUT${NC}"
    iptables -L INPUT -n --line-numbers | grep "172.18.0.0/16" | head -5
else
    echo -e "${YELLOW}! Subnet 172.18.0.0/16 no encontrada en INPUT${NC}"
fi

# 3. Verificar interfaces Docker
echo
echo -e "${YELLOW}[3/6] Verificando interfaces Docker...${NC}"
if ip link show docker0 &>/dev/null; then
    echo -e "${GREEN}✓ Interfaz docker0 existe${NC}"
    if iptables -L INPUT -n | grep -q "docker0"; then
        echo -e "${GREEN}✓ docker0 permitida en INPUT${NC}"
    fi
else
    echo -e "${YELLOW}! Interfaz docker0 no encontrada${NC}"
fi

if ip link show pterodactyl_nw &>/dev/null; then
    echo -e "${GREEN}✓ Interfaz pterodactyl_nw existe${NC}"
else
    echo -e "${YELLOW}! Interfaz pterodactyl_nw no encontrada (normal si Wings no está corriendo)${NC}"
fi

# 4. Verificar cadena ANTIDDOS
echo
echo -e "${YELLOW}[4/6] Verificando cadena ANTIDDOS...${NC}"
if iptables -L ANTIDDOS -n &>/dev/null; then
    echo -e "${GREEN}✓ Cadena ANTIDDOS existe${NC}"
    ANTIDDOS_RULES=$(iptables -L ANTIDDOS -n | wc -l)
    echo -e "${GREEN}  Reglas en ANTIDDOS: $ANTIDDOS_RULES${NC}"
else
    echo -e "${YELLOW}! Cadena ANTIDDOS no existe (normal si no está instalado)${NC}"
fi

# 5. Verificar política FORWARD
echo
echo -e "${YELLOW}[5/6] Verificando política FORWARD...${NC}"
FORWARD_POLICY=$(iptables -L FORWARD -n | head -1 | grep -o "policy [A-Z]*" | awk '{print $2}')
if [ "$FORWARD_POLICY" = "ACCEPT" ] || [ "$FORWARD_POLICY" = "DROP" ]; then
    echo -e "${GREEN}✓ Política FORWARD: $FORWARD_POLICY${NC}"
    if [ "$FORWARD_POLICY" = "DROP" ]; then
        echo -e "${YELLOW}  Nota: FORWARD está en DROP, pero Docker tiene sus propias reglas${NC}"
    fi
else
    echo -e "${YELLOW}! No se pudo determinar política FORWARD${NC}"
fi

# Verificar que hay reglas de Docker en FORWARD
if iptables -L FORWARD -n | grep -q "docker0"; then
    echo -e "${GREEN}✓ Reglas de Docker en FORWARD${NC}"
fi

# 6. Verificar configuración de Wings
echo
echo -e "${YELLOW}[6/6] Verificando configuración de Wings...${NC}"
if [ -f /etc/pterodactyl/config.yml ]; then
    echo -e "${GREEN}✓ Archivo de configuración de Wings existe${NC}"
    
    # Extraer subnet de Wings
    WINGS_SUBNET=$(grep -A 10 "interfaces:" /etc/pterodactyl/config.yml | grep "subnet:" | awk '{print $2}')
    if [ ! -z "$WINGS_SUBNET" ]; then
        echo -e "${GREEN}  Subnet configurada en Wings: $WINGS_SUBNET${NC}"
        
        # Verificar que está protegida
        if iptables -L INPUT -n | grep -q "$WINGS_SUBNET"; then
            echo -e "${GREEN}✓ Esta subnet está protegida en iptables${NC}"
        else
            echo -e "${YELLOW}! Esta subnet NO está protegida en iptables${NC}"
        fi
    fi
else
    echo -e "${YELLOW}! Archivo de configuración de Wings no encontrado${NC}"
fi

# RESUMEN
echo
echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    RESUMEN                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo

echo -e "${GREEN}Estado de Protecciones:${NC}"
echo

# Verificar que Docker está funcionando
if systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓ Docker está activo y funcionando${NC}"
else
    echo -e "${RED}✗ Docker no está activo${NC}"
fi

# Verificar que Wings está funcionando
if systemctl is-active --quiet wings; then
    echo -e "${GREEN}✓ Wings está activo y funcionando${NC}"
else
    echo -e "${YELLOW}! Wings no está activo${NC}"
fi

# Verificar que las cadenas críticas existen
CRITICAL_CHAINS=("DOCKER" "FORWARD" "INPUT")
for chain in "${CRITICAL_CHAINS[@]}"; do
    if [ "$chain" = "DOCKER" ]; then
        if iptables -t nat -L $chain -n &>/dev/null; then
            echo -e "${GREEN}✓ Cadena $chain intacta${NC}"
        else
            echo -e "${RED}✗ Cadena $chain no encontrada${NC}"
        fi
    else
        if iptables -L $chain -n &>/dev/null; then
            echo -e "${GREEN}✓ Cadena $chain intacta${NC}"
        else
            echo -e "${RED}✗ Cadena $chain no encontrada${NC}"
        fi
    fi
done

echo
echo -e "${BLUE}Comandos útiles:${NC}"
echo
echo "Ver reglas de Docker NAT:"
echo "  sudo iptables -t nat -L DOCKER -n -v"
echo
echo "Ver subnet protegida:"
echo "  sudo iptables -L INPUT -n | grep 172.18.0"
echo
echo "Ver todas las reglas:"
echo "  sudo iptables -L -n -v --line-numbers"
echo
echo "Ver configuración de Wings:"
echo "  sudo cat /etc/pterodactyl/config.yml | grep -A 20 'interfaces:'"
echo
echo "Ver logs de Anti-DDoS:"
echo "  sudo tail -f /var/log/antiddos/antiddos.log"
echo

echo -e "${GREEN}✓ Verificación completa${NC}"
