#!/bin/bash

# Script para limpiar manualmente las reglas ANTIDDOS en sistemas nftables
# Usar SOLO si el cleanup automático no funcionó

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}=== Limpieza Manual Anti-DDoS (nftables) ===${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
    exit 1
fi

# Detectar sistema
if command -v nft &> /dev/null; then
    echo -e "${GREEN}✓ nft detectado - sistema usa nftables${NC}"
    USE_NFT=true
elif command -v iptables-nft &> /dev/null; then
    echo -e "${GREEN}✓ iptables-nft detectado${NC}"
    IPTABLES="iptables-nft"
    USE_NFT=false
else
    echo -e "${YELLOW}⚠ Usando iptables estándar${NC}"
    IPTABLES="iptables"
    USE_NFT=false
fi

echo

# Detener servicio primero
echo -e "${YELLOW}[1/4] Deteniendo servicios Anti-DDoS...${NC}"
systemctl stop antiddos-monitor 2>/dev/null && echo "  ✓ antiddos-monitor detenido"
systemctl stop antiddos-ssh 2>/dev/null && echo "  ✓ antiddos-ssh detenido"
sleep 2

# Limpieza con nftables
if [ "$USE_NFT" = true ]; then
    echo
    echo -e "${YELLOW}[2/4] Verificando cadenas con nft...${NC}"
    
    # Ver si existe la tabla filter
    if nft list table ip filter &>/dev/null; then
        # Listar todas las cadenas ANTIDDOS
        chains=$(nft list table ip filter | grep "chain ANTIDDOS" | awk '{print $2}')
        
        if [ -z "$chains" ]; then
            echo -e "  ${GREEN}✓ No se encontraron cadenas ANTIDDOS${NC}"
        else
            echo -e "  ${YELLOW}Cadenas ANTIDDOS encontradas:${NC}"
            echo "$chains" | while read chain; do
                echo "    - $chain"
            done
            
            echo
            echo -e "${YELLOW}[3/4] Eliminando saltos a cadenas ANTIDDOS...${NC}"
            
            # Eliminar referencias en otras cadenas
            # Primero, obtener el handle de las reglas que saltan a ANTIDDOS
            nft -a list table ip filter | grep -B1 "jump ANTIDDOS" | grep "handle" | awk '{print $NF}' | while read handle; do
                if [ ! -z "$handle" ]; then
                    # Determinar en qué cadena está (INPUT, FORWARD, OUTPUT)
                    chain=$(nft -a list table ip filter | grep -B2 "handle $handle" | grep "chain" | head -1 | awk '{print $2}')
                    echo "  Removiendo regla handle $handle de $chain"
                    nft delete rule ip filter "$chain" handle "$handle" 2>/dev/null
                fi
            done
            
            echo
            echo -e "${YELLOW}[4/4] Eliminando cadenas ANTIDDOS...${NC}"
            
            # Eliminar todas las cadenas ANTIDDOS
            echo "$chains" | while read chain; do
                echo "  Eliminando cadena: $chain"
                # Primero flush, luego delete
                nft flush chain ip filter "$chain" 2>/dev/null
                nft delete chain ip filter "$chain" 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo -e "    ${GREEN}✓ $chain eliminada${NC}"
                else
                    echo -e "    ${RED}✗ Error eliminando $chain${NC}"
                fi
            done
        fi
    else
        echo -e "  ${GREEN}✓ Tabla ip filter no existe - sistema limpio${NC}"
    fi

# Limpieza con iptables-nft
else
    echo
    echo -e "${YELLOW}[2/4] Verificando cadenas con $IPTABLES...${NC}"
    
    # Listar cadenas
    chains=$($IPTABLES -S | grep "^-N ANTIDDOS" | awk '{print $2}')
    
    if [ -z "$chains" ]; then
        echo -e "  ${GREEN}✓ No se encontraron cadenas ANTIDDOS${NC}"
    else
        echo -e "  ${YELLOW}Cadenas ANTIDDOS encontradas:${NC}"
        echo "$chains" | while read chain; do
            echo "    - $chain"
        done
        
        echo
        echo -e "${YELLOW}[3/4] Eliminando saltos a cadenas ANTIDDOS...${NC}"
        
        # Eliminar saltos de INPUT
        removed=0
        while $IPTABLES -D INPUT -j ANTIDDOS 2>/dev/null; do
            removed=$((removed + 1))
        done
        [ $removed -gt 0 ] && echo "  ✓ Removidos $removed saltos de INPUT"
        
        # Eliminar saltos de FORWARD
        removed=0
        while $IPTABLES -D FORWARD -j ANTIDDOS 2>/dev/null; do
            removed=$((removed + 1))
        done
        [ $removed -gt 0 ] && echo "  ✓ Removidos $removed saltos de FORWARD"
        
        # Eliminar saltos de OUTPUT
        removed=0
        while $IPTABLES -D OUTPUT -j ANTIDDOS 2>/dev/null; do
            removed=$((removed + 1))
        done
        [ $removed -gt 0 ] && echo "  ✓ Removidos $removed saltos de OUTPUT"
        
        echo
        echo -e "${YELLOW}[4/4] Eliminando cadenas ANTIDDOS...${NC}"
        
        # Eliminar todas las cadenas
        echo "$chains" | while read chain; do
            echo "  Eliminando cadena: $chain"
            $IPTABLES -F "$chain" 2>/dev/null
            $IPTABLES -X "$chain" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "    ${GREEN}✓ $chain eliminada${NC}"
            else
                echo -e "    ${RED}✗ Error eliminando $chain${NC}"
            fi
        done
    fi
fi

# Verificación final
echo
echo -e "${BLUE}=== Verificación Final ===${NC}"
echo

if [ "$USE_NFT" = true ]; then
    if nft list table ip filter 2>/dev/null | grep -q "chain ANTIDDOS"; then
        echo -e "${RED}❌ FAIL: Todavía existen cadenas ANTIDDOS${NC}"
        echo
        nft list table ip filter | grep "chain ANTIDDOS"
        exit 1
    else
        echo -e "${GREEN}✓ ÉXITO: Sistema limpio - no hay cadenas ANTIDDOS${NC}"
    fi
else
    if $IPTABLES -L ANTIDDOS -n &>/dev/null; then
        echo -e "${RED}❌ FAIL: Todavía existe la cadena ANTIDDOS${NC}"
        exit 1
    else
        echo -e "${GREEN}✓ ÉXITO: Sistema limpio - no hay cadenas ANTIDDOS${NC}"
    fi
fi

echo
echo -e "${GREEN}=== Limpieza Completada ===${NC}"
echo
echo "Ahora puedes:"
echo "  1. Probar que los jugadores pueden conectar"
echo "  2. Actualizar el código Anti-DDoS"
echo "  3. Reiniciar el servicio con 'systemctl start antiddos-monitor'"
echo
