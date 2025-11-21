#!/bin/bash

# Script para verificar el cleanup correcto del servicio Anti-DDoS
# Compatible con nftables backend

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Verificación de Cleanup Anti-DDoS ===${NC}"
echo

# Detectar qué comando de iptables usar
if command -v iptables-nft &> /dev/null && iptables-nft -L -n &>/dev/null 2>&1; then
    IPTABLES="iptables-nft"
    echo -e "${GREEN}Detectado: iptables-nft (nftables backend)${NC}"
elif command -v nft &> /dev/null; then
    # Sistema usa nftables nativo
    echo -e "${GREEN}Detectado: nftables nativo${NC}"
    echo
    echo "Verificando reglas con nft..."
    
    # Ver si existe la tabla filter
    if nft list table ip filter &>/dev/null; then
        # Buscar cadena ANTIDDOS
        if nft list table ip filter | grep -q "chain ANTIDDOS"; then
            echo -e "${RED}❌ FAIL: Cadena ANTIDDOS todavía existe${NC}"
            echo
            echo "Reglas actuales:"
            nft list table ip filter | grep -A 10 "chain ANTIDDOS"
            echo
            echo -e "${YELLOW}El cleanup NO funcionó. Las reglas siguen activas.${NC}"
            exit 1
        else
            echo -e "${GREEN}✓ PASS: Cadena ANTIDDOS no existe${NC}"
            exit 0
        fi
    else
        echo -e "${YELLOW}Tabla ip filter no existe - sistema limpio${NC}"
        exit 0
    fi
else
    IPTABLES="iptables"
    echo -e "${YELLOW}Usando: iptables (verificar backend)${NC}"
fi

# Verificar con iptables
echo
echo "Verificando reglas con $IPTABLES..."

# Intentar listar la cadena ANTIDDOS
output=$($IPTABLES -L ANTIDDOS -n 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo -e "${RED}❌ FAIL: Cadena ANTIDDOS todavía existe${NC}"
    echo
    echo "Reglas en ANTIDDOS:"
    $IPTABLES -L ANTIDDOS -n -v
    echo
    echo -e "${YELLOW}El cleanup NO funcionó. Las reglas siguen activas.${NC}"
    echo
    echo "Comandos para limpiar manualmente:"
    echo "  sudo $IPTABLES -D INPUT -j ANTIDDOS 2>/dev/null"
    echo "  sudo $IPTABLES -D FORWARD -j ANTIDDOS 2>/dev/null"
    echo "  sudo $IPTABLES -F ANTIDDOS"
    echo "  sudo $IPTABLES -X ANTIDDOS"
    exit 1
elif echo "$output" | grep -q "No chain/target/match by that name"; then
    echo -e "${GREEN}✓ PASS: Cadena ANTIDDOS no existe (limpiado correctamente)${NC}"
    exit 0
elif echo "$output" | grep -q "incompatible.*use 'nft' tool"; then
    echo -e "${YELLOW}⚠ WARNING: Sistema usa nftables, verificando con nft...${NC}"
    
    if command -v nft &> /dev/null; then
        if nft list table ip filter | grep -q "chain ANTIDDOS"; then
            echo -e "${RED}❌ FAIL: Cadena ANTIDDOS existe en nftables${NC}"
            echo
            nft list table ip filter | grep -A 10 "chain ANTIDDOS"
            echo
            echo "Comando para limpiar manualmente:"
            echo "  sudo nft delete chain ip filter ANTIDDOS"
            exit 1
        else
            echo -e "${GREEN}✓ PASS: Cadena ANTIDDOS no existe${NC}"
            exit 0
        fi
    else
        echo -e "${RED}❌ ERROR: nft no está instalado pero el sistema usa nftables${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ Resultado inesperado:${NC}"
    echo "$output"
    exit 1
fi
