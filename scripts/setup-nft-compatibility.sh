#!/bin/bash

# Script para configurar el sistema para usar iptables-nft
# Compatible con Docker y Pterodactyl

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Configuración de iptables-nft para Docker/Pterodactyl ===${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/6] Configurando update-alternatives para usar nft...${NC}"

# Configurar iptables para usar nft
update-alternatives --set iptables /usr/sbin/iptables-nft 2>/dev/null
update-alternatives --set ip6tables /usr/sbin/ip6tables-nft 2>/dev/null
update-alternatives --set arptables /usr/sbin/arptables-nft 2>/dev/null
update-alternatives --set ebtables /usr/sbin/ebtables-nft 2>/dev/null

echo -e "${GREEN}✓ Alternativas configuradas${NC}"

echo
echo -e "${YELLOW}[2/6] Limpiando iptables-legacy...${NC}"

# Limpiar completamente iptables-legacy
iptables-legacy -F 2>/dev/null
iptables-legacy -X 2>/dev/null
iptables-legacy -t nat -F 2>/dev/null
iptables-legacy -t nat -X 2>/dev/null
iptables-legacy -t mangle -F 2>/dev/null
iptables-legacy -t mangle -X 2>/dev/null

# Política ACCEPT en legacy
iptables-legacy -P INPUT ACCEPT 2>/dev/null
iptables-legacy -P FORWARD ACCEPT 2>/dev/null
iptables-legacy -P OUTPUT ACCEPT 2>/dev/null

echo -e "${GREEN}✓ iptables-legacy limpiado${NC}"

echo
echo -e "${YELLOW}[3/6] Verificando backend de iptables...${NC}"

# Verificar que iptables usa nft
IPTABLES_VERSION=$(iptables --version)
echo "  Versión: $IPTABLES_VERSION"

if echo "$IPTABLES_VERSION" | grep -q "nf_tables"; then
    echo -e "${GREEN}✓ iptables está usando backend nf_tables${NC}"
else
    echo -e "${YELLOW}! Advertencia: iptables podría no estar usando nf_tables${NC}"
fi

echo
echo -e "${YELLOW}[4/6] Configurando Docker para usar iptables...${NC}"

# Asegurar que Docker use iptables
DOCKER_DAEMON="/etc/docker/daemon.json"

if [ ! -f "$DOCKER_DAEMON" ]; then
    echo '{"iptables": true}' > "$DOCKER_DAEMON"
    echo -e "${GREEN}✓ Creado $DOCKER_DAEMON${NC}"
else
    # Verificar si ya tiene iptables configurado
    if ! grep -q '"iptables"' "$DOCKER_DAEMON"; then
        # Agregar iptables: true al JSON existente
        tmp=$(mktemp)
        jq '. + {"iptables": true}' "$DOCKER_DAEMON" > "$tmp" 2>/dev/null && mv "$tmp" "$DOCKER_DAEMON"
        echo -e "${GREEN}✓ Actualizado $DOCKER_DAEMON${NC}"
    else
        echo -e "${GREEN}✓ Docker ya configurado para usar iptables${NC}"
    fi
fi

echo
echo -e "${YELLOW}[5/6] Reiniciando servicios...${NC}"

# Reiniciar Docker
systemctl restart docker
echo "  ✓ Docker reiniciado"

# Reiniciar Wings si existe
if systemctl is-active --quiet wings; then
    systemctl restart wings
    echo "  ✓ Wings reiniciado"
fi

echo
echo -e "${YELLOW}[6/6] Verificando configuración...${NC}"

# Verificar que Docker está corriendo
if systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓ Docker está activo${NC}"
else
    echo -e "${RED}✗ Docker no está activo${NC}"
fi

# Verificar reglas de Docker
if iptables -t nat -L DOCKER -n &>/dev/null; then
    echo -e "${GREEN}✓ Cadena DOCKER existe en iptables${NC}"
else
    echo -e "${YELLOW}! Cadena DOCKER no encontrada${NC}"
fi

echo
echo -e "${GREEN}=== Configuración Completada ===${NC}"
echo
echo -e "${BLUE}Resumen:${NC}"
echo "  ✓ iptables configurado para usar nft backend"
echo "  ✓ iptables-legacy limpiado"
echo "  ✓ Docker configurado para usar iptables"
echo "  ✓ Servicios reiniciados"
echo
echo -e "${BLUE}Verificación:${NC}"
echo "Ver versión de iptables:"
echo "  iptables --version"
echo
echo "Ver reglas de Docker:"
echo "  iptables -t nat -L DOCKER -n"
echo
echo "Ver alternativas:"
echo "  update-alternatives --display iptables"
echo
echo -e "${GREEN}✓ Sistema configurado para compatibilidad con Docker/Pterodactyl${NC}"
