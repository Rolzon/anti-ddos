#!/bin/bash

# Script para corregir el orden de reglas de iptables
# Asegura que las reglas ACCEPT estén ANTES del salto a ANTIDDOS

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Corrección de Orden de Reglas ===${NC}"
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

echo -e "${YELLOW}[1/5] Estado actual de INPUT...${NC}"
$IPTABLES -L INPUT -n --line-numbers | head -20
echo

echo -e "${YELLOW}[2/5] Removiendo salto a ANTIDDOS de INPUT...${NC}"
# Remover TODAS las referencias a ANTIDDOS en INPUT
removed=0
while $IPTABLES -D INPUT -j ANTIDDOS 2>/dev/null; do
    removed=$((removed + 1))
    echo "  Removido salto $removed"
done

if [ $removed -eq 0 ]; then
    echo "  No se encontraron saltos a ANTIDDOS"
else
    echo -e "${GREEN}  ✓ $removed salto(s) removido(s)${NC}"
fi

echo
echo -e "${YELLOW}[3/5] Limpiando reglas duplicadas...${NC}"

# Función para limpiar reglas duplicadas
clean_duplicates() {
    local chain=$1
    local port=$2
    local proto=$3
    
    # Contar cuántas veces aparece
    count=$($IPTABLES -L $chain -n | grep -c "dpt:$port")
    
    if [ $count -gt 1 ]; then
        echo "  Puerto $port/$proto tiene $count reglas, limpiando..."
        # Remover todas
        while $IPTABLES -D $chain -p $proto --dport $port -j ACCEPT 2>/dev/null; do
            :
        done
    fi
}

# Limpiar duplicados en INPUT
clean_duplicates INPUT 8080 tcp
clean_duplicates INPUT 2022 tcp
clean_duplicates INPUT 25565 tcp
clean_duplicates INPUT 25565 udp
clean_duplicates INPUT 19132 tcp
clean_duplicates INPUT 19132 udp

echo -e "${GREEN}  ✓ Duplicados limpiados${NC}"

echo
echo -e "${YELLOW}[4/5] Aplicando reglas en orden correcto...${NC}"
echo

# ORDEN CORRECTO:
# 1. Loopback (siempre primero)
# 2. Conexiones establecidas
# 3. Docker
# 4. Puertos específicos
# 5. Salto a ANTIDDOS (al final)

echo "  [1] Permitir loopback..."
$IPTABLES -D INPUT -i lo -j ACCEPT 2>/dev/null
$IPTABLES -I INPUT 1 -i lo -j ACCEPT

echo "  [2] Permitir conexiones establecidas..."
$IPTABLES -D INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null
$IPTABLES -I INPUT 2 -m state --state ESTABLISHED,RELATED -j ACCEPT

echo "  [3] Permitir Docker..."
$IPTABLES -D INPUT -i docker0 -j ACCEPT 2>/dev/null
$IPTABLES -I INPUT 3 -i docker0 -j ACCEPT

echo "  [4] Permitir redes privadas..."
$IPTABLES -D INPUT -s 172.16.0.0/12 -j ACCEPT 2>/dev/null
$IPTABLES -I INPUT 4 -s 172.16.0.0/12 -j ACCEPT
$IPTABLES -D INPUT -s 10.0.0.0/8 -j ACCEPT 2>/dev/null
$IPTABLES -I INPUT 5 -s 10.0.0.0/8 -j ACCEPT

echo "  [5] Permitir puerto Wings (8080)..."
$IPTABLES -I INPUT 6 -p tcp --dport 8080 -j ACCEPT

echo "  [6] Permitir puerto SFTP (2022)..."
$IPTABLES -I INPUT 7 -p tcp --dport 2022 -j ACCEPT

echo "  [7] Permitir puerto SSH (22)..."
$IPTABLES -D INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null
$IPTABLES -I INPUT 8 -p tcp --dport 22 -j ACCEPT

echo "  [8] Permitir Minecraft Java (25565)..."
$IPTABLES -I INPUT 9 -p tcp --dport 25565 -j ACCEPT
$IPTABLES -I INPUT 10 -p udp --dport 25565 -j ACCEPT

echo "  [9] Permitir Minecraft Bedrock (19132)..."
$IPTABLES -I INPUT 11 -p tcp --dport 19132 -j ACCEPT
$IPTABLES -I INPUT 12 -p udp --dport 19132 -j ACCEPT

echo "  [10] Permitir rango Pterodactyl (19133-20100)..."
$IPTABLES -I INPUT 13 -p tcp --dport 19133:20100 -j ACCEPT
$IPTABLES -I INPUT 14 -p udp --dport 19133:20100 -j ACCEPT

echo "  [11] Permitir HTTP/HTTPS..."
$IPTABLES -D INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null
$IPTABLES -D INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null
$IPTABLES -I INPUT 15 -p tcp --dport 80 -j ACCEPT
$IPTABLES -I INPUT 16 -p tcp --dport 443 -j ACCEPT

echo "  [12] Permitir MySQL (3306) desde IP específica..."
$IPTABLES -D INPUT -s 190.57.138.18 -p tcp --dport 3306 -j ACCEPT 2>/dev/null
$IPTABLES -I INPUT 17 -s 190.57.138.18 -p tcp --dport 3306 -j ACCEPT

echo "  [13] Agregar salto a ANTIDDOS al FINAL..."
# Verificar si ANTIDDOS existe
if $IPTABLES -L ANTIDDOS -n &>/dev/null; then
    $IPTABLES -A INPUT -j ANTIDDOS
    echo -e "${GREEN}  ✓ Salto a ANTIDDOS agregado al final${NC}"
else
    echo -e "${YELLOW}  ! Cadena ANTIDDOS no existe, saltando${NC}"
fi

echo
echo -e "${GREEN}✓ Reglas aplicadas en orden correcto${NC}"

echo
echo -e "${YELLOW}[5/5] Aplicando mismas reglas a FORWARD...${NC}"

# Limpiar FORWARD
$IPTABLES -D FORWARD -i docker0 -j ACCEPT 2>/dev/null
$IPTABLES -D FORWARD -o docker0 -j ACCEPT 2>/dev/null

# Agregar reglas a FORWARD para Docker
$IPTABLES -I FORWARD 1 -i docker0 -j ACCEPT
$IPTABLES -I FORWARD 2 -o docker0 -j ACCEPT
$IPTABLES -I FORWARD 3 -m state --state ESTABLISHED,RELATED -j ACCEPT

echo -e "${GREEN}✓ Reglas FORWARD configuradas${NC}"

# Guardar reglas
echo
echo "Guardando reglas..."
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save &>/dev/null
    echo -e "${GREEN}✓ Reglas guardadas con netfilter-persistent${NC}"
elif command -v iptables-save &> /dev/null; then
    iptables-save > /etc/iptables/rules.v4 2>/dev/null
    echo -e "${GREEN}✓ Reglas guardadas con iptables-save${NC}"
fi

echo
echo -e "${GREEN}=== Corrección Completada ===${NC}"
echo
echo -e "${BLUE}Nuevas primeras 20 reglas de INPUT:${NC}"
$IPTABLES -L INPUT -n --line-numbers | head -25

echo
echo -e "${BLUE}Verificación:${NC}"
echo "1. Ver todas las reglas:"
echo "   sudo $IPTABLES -L -n -v --line-numbers"
echo
echo "2. Probar puerto desde fuera:"
echo "   nc -zv TU_IP 25565"
echo
echo "3. Ver puertos escuchando:"
echo "   sudo ss -tulnp | grep -E '8080|25565|19132'"
echo
echo "4. Reiniciar Wings:"
echo "   sudo systemctl restart wings"
echo
echo -e "${GREEN}✓ Los puertos deberían estar accesibles ahora${NC}"
