#!/bin/bash

# Script para desbloquear completamente MariaDB/MySQL para una IP específica
# Elimina TODOS los límites y restricciones para la IP 190.57.138.18

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# IP a desbloquear
TARGET_IP="190.57.138.18"
MARIADB_PORT="3306"

echo -e "${GREEN}=== Desbloqueo Completo de MariaDB/MySQL ===${NC}"
echo -e "${BLUE}IP: $TARGET_IP${NC}"
echo -e "${BLUE}Puerto: $MARIADB_PORT${NC}"
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
    echo -e "${YELLOW}! Cadena ANTIDDOS no existe (sistema no instalado o no activo)${NC}"
    HAS_ANTIDDOS=false
fi

# Eliminar reglas restrictivas
echo
echo -e "${YELLOW}[3/5] Eliminando TODAS las reglas restrictivas para $TARGET_IP...${NC}"

if [ "$HAS_ANTIDDOS" = true ]; then
    # Eliminar de cadena ANTIDDOS
    echo "Limpiando cadena ANTIDDOS..."
    
    # Eliminar todas las reglas que mencionen la IP y el puerto
    $IPTABLES -L ANTIDDOS -n --line-numbers | grep "$TARGET_IP" | grep "$MARIADB_PORT" | tac | while read line; do
        line_num=$(echo $line | awk '{print $1}')
        if [[ $line_num =~ ^[0-9]+$ ]]; then
            $IPTABLES -D ANTIDDOS $line_num 2>/dev/null && echo "  ✓ Eliminada regla ANTIDDOS #$line_num"
        fi
    done
fi

# Eliminar de cadena INPUT
echo "Limpiando cadena INPUT..."
$IPTABLES -L INPUT -n --line-numbers | grep "$TARGET_IP" | grep "$MARIADB_PORT" | tac | while read line; do
    line_num=$(echo $line | awk '{print $1}')
    if [[ $line_num =~ ^[0-9]+$ ]]; then
        $IPTABLES -D INPUT $line_num 2>/dev/null && echo "  ✓ Eliminada regla INPUT #$line_num"
    fi
done

echo -e "${GREEN}✓ Reglas restrictivas eliminadas${NC}"

# Agregar regla de ACCEPT al inicio
echo
echo -e "${YELLOW}[4/5] Agregando regla de ACCEPT (prioridad máxima)...${NC}"

if [ "$HAS_ANTIDDOS" = true ]; then
    # Agregar en ANTIDDOS (prioridad 1)
    $IPTABLES -I ANTIDDOS 1 -s "$TARGET_IP" -p tcp --dport "$MARIADB_PORT" -j ACCEPT
    echo -e "${GREEN}✓ Regla agregada en ANTIDDOS (posición 1)${NC}"
fi

# Agregar en INPUT también (por si acaso)
$IPTABLES -I INPUT 1 -s "$TARGET_IP" -p tcp --dport "$MARIADB_PORT" -j ACCEPT
echo -e "${GREEN}✓ Regla agregada en INPUT (posición 1)${NC}"

# Agregar a whitelist
echo
echo -e "${YELLOW}[5/5] Agregando IP a whitelist...${NC}"
if [ -f /etc/antiddos/whitelist.txt ]; then
    if ! grep -q "$TARGET_IP" /etc/antiddos/whitelist.txt; then
        echo "$TARGET_IP  # IP pública - Acceso completo MariaDB/MySQL" >> /etc/antiddos/whitelist.txt
        echo -e "${GREEN}✓ IP agregada a whitelist${NC}"
    else
        echo -e "${YELLOW}! IP ya está en whitelist${NC}"
    fi
else
    echo -e "${YELLOW}! Whitelist no existe (sistema no instalado)${NC}"
fi

# Guardar reglas
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save &>/dev/null
    echo -e "${GREEN}✓ Reglas guardadas permanentemente${NC}"
fi

echo
echo -e "${GREEN}=== Desbloqueo Completado ===${NC}"
echo
echo -e "${BLUE}Configuración aplicada:${NC}"
echo "  ✓ IP: $TARGET_IP"
echo "  ✓ Puerto: $MARIADB_PORT (MariaDB/MySQL)"
echo "  ✓ Acceso: ILIMITADO"
echo "  ✓ Prioridad: MÁXIMA (regla #1)"
echo "  ✓ Límites: NINGUNO"
echo

echo -e "${BLUE}Reglas activas para $TARGET_IP:${NC}"
if [ "$HAS_ANTIDDOS" = true ]; then
    echo "ANTIDDOS:"
    $IPTABLES -L ANTIDDOS -n -v --line-numbers | grep "$TARGET_IP" | head -5
fi
echo "INPUT:"
$IPTABLES -L INPUT -n -v --line-numbers | grep "$TARGET_IP" | head -5

echo
echo -e "${GREEN}✓ MariaDB/MySQL completamente desbloqueado para $TARGET_IP${NC}"
echo
echo -e "${YELLOW}Verificación:${NC}"
echo "  Probar conexión:"
echo "    mysql -h $TARGET_IP -u usuario -p"
echo
echo "  Ver conexiones activas:"
echo "    sudo ss -tnp | grep :$MARIADB_PORT"
echo
echo "  Ver todas las reglas:"
echo "    sudo $IPTABLES -L -n -v | grep $TARGET_IP"
