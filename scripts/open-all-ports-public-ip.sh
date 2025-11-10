#!/bin/bash

# Script para abrir TODOS los puertos necesarios para la IP pública 190.57.138.18
# y también globalmente para que los jugadores puedan conectarse

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Apertura Total de Puertos Pterodactyl ===${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
    exit 1
fi

# IP pública del servidor
PUBLIC_IP="190.57.138.18"

# Detectar iptables
if command -v iptables-legacy &> /dev/null && iptables-legacy -L -n &>/dev/null 2>&1; then
    IPTABLES="iptables-legacy"
else
    IPTABLES="iptables"
fi

echo -e "${BLUE}Usando: $IPTABLES${NC}"
echo -e "${BLUE}IP Pública: $PUBLIC_IP${NC}"
echo

echo -e "${YELLOW}[1/8] Deteniendo servicio antiddos-monitor temporalmente...${NC}"
systemctl stop antiddos-monitor 2>/dev/null
echo -e "${GREEN}✓ Servicio detenido${NC}"

echo
echo -e "${YELLOW}[2/8] Limpiando cadena ANTIDDOS...${NC}"
if $IPTABLES -L ANTIDDOS -n &>/dev/null; then
    $IPTABLES -F ANTIDDOS
    echo -e "${GREEN}✓ Cadena ANTIDDOS limpiada${NC}"
else
    echo -e "${YELLOW}! Cadena ANTIDDOS no existe${NC}"
fi

echo
echo -e "${YELLOW}[3/8] Removiendo salto a ANTIDDOS de INPUT...${NC}"
while $IPTABLES -D INPUT -j ANTIDDOS 2>/dev/null; do
    echo "  Removido salto a ANTIDDOS"
done
echo -e "${GREEN}✓ Saltos removidos${NC}"

echo
echo -e "${YELLOW}[4/8] Limpiando reglas existentes de puertos...${NC}"

# Función para limpiar puerto
clean_port() {
    local port=$1
    local proto=$2
    while $IPTABLES -D INPUT -p $proto --dport $port -j ACCEPT 2>/dev/null; do
        :
    done
}

clean_port 8080 tcp
clean_port 2022 tcp
clean_port 22 tcp
clean_port 80 tcp
clean_port 443 tcp
clean_port 3306 tcp
clean_port 25565 tcp
clean_port 25565 udp
clean_port 19132 tcp
clean_port 19132 udp

echo -e "${GREEN}✓ Reglas antiguas limpiadas${NC}"

echo
echo -e "${YELLOW}[5/8] Configurando política por defecto...${NC}"
$IPTABLES -P INPUT ACCEPT
$IPTABLES -P FORWARD ACCEPT
$IPTABLES -P OUTPUT ACCEPT
echo -e "${GREEN}✓ Política ACCEPT configurada${NC}"

echo
echo -e "${YELLOW}[6/8] Aplicando reglas básicas...${NC}"

# Loopback
$IPTABLES -A INPUT -i lo -j ACCEPT
echo "  ✓ Loopback permitido"

# Conexiones establecidas
$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
echo "  ✓ Conexiones establecidas permitidas"

# Docker
$IPTABLES -A INPUT -i docker0 -j ACCEPT
$IPTABLES -A FORWARD -i docker0 -j ACCEPT
$IPTABLES -A FORWARD -o docker0 -j ACCEPT
echo "  ✓ Docker permitido"

# Redes privadas
$IPTABLES -A INPUT -s 172.16.0.0/12 -j ACCEPT
$IPTABLES -A INPUT -s 10.0.0.0/8 -j ACCEPT
$IPTABLES -A INPUT -s 192.168.0.0/16 -j ACCEPT
echo "  ✓ Redes privadas permitidas"

echo
echo -e "${YELLOW}[7/8] Abriendo TODOS los puertos necesarios...${NC}"
echo

# SSH
$IPTABLES -A INPUT -p tcp --dport 22 -j ACCEPT
echo "  ✓ Puerto 22 (SSH) - GLOBAL"

# HTTP/HTTPS
$IPTABLES -A INPUT -p tcp --dport 80 -j ACCEPT
$IPTABLES -A INPUT -p tcp --dport 443 -j ACCEPT
echo "  ✓ Puertos 80/443 (HTTP/HTTPS) - GLOBAL"

# Wings
$IPTABLES -A INPUT -p tcp --dport 8080 -j ACCEPT
echo "  ✓ Puerto 8080 (Wings) - GLOBAL"

# SFTP
$IPTABLES -A INPUT -p tcp --dport 2022 -j ACCEPT
echo "  ✓ Puerto 2022 (SFTP) - GLOBAL"

# MySQL - Solo desde IP pública del servidor
$IPTABLES -A INPUT -s $PUBLIC_IP -p tcp --dport 3306 -j ACCEPT
$IPTABLES -A INPUT -s 127.0.0.1 -p tcp --dport 3306 -j ACCEPT
echo "  ✓ Puerto 3306 (MySQL) - Solo desde $PUBLIC_IP y localhost"

# Minecraft Java - GLOBAL (para que jugadores puedan conectar)
$IPTABLES -A INPUT -p tcp --dport 25565 -j ACCEPT
$IPTABLES -A INPUT -p udp --dport 25565 -j ACCEPT
echo "  ✓ Puerto 25565 (Minecraft Java) - GLOBAL TCP/UDP"

# Minecraft Bedrock - GLOBAL
$IPTABLES -A INPUT -p tcp --dport 19132 -j ACCEPT
$IPTABLES -A INPUT -p udp --dport 19132 -j ACCEPT
echo "  ✓ Puerto 19132 (Minecraft Bedrock) - GLOBAL TCP/UDP"

# Rango completo Pterodactyl - GLOBAL
$IPTABLES -A INPUT -p tcp --dport 19133:20100 -j ACCEPT
$IPTABLES -A INPUT -p udp --dport 19133:20100 -j ACCEPT
echo "  ✓ Puertos 19133-20100 (Pterodactyl) - GLOBAL TCP/UDP"

echo
echo -e "${GREEN}✓ Todos los puertos abiertos${NC}"

echo
echo -e "${YELLOW}[8/8] Guardando reglas permanentemente...${NC}"

if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save &>/dev/null
    echo -e "${GREEN}✓ Reglas guardadas con netfilter-persistent${NC}"
elif [ -d /etc/iptables ]; then
    $IPTABLES-save > /etc/iptables/rules.v4
    echo -e "${GREEN}✓ Reglas guardadas en /etc/iptables/rules.v4${NC}"
fi

echo
echo -e "${YELLOW}Reiniciando servicios...${NC}"
systemctl restart docker
systemctl restart wings
systemctl start antiddos-monitor
echo -e "${GREEN}✓ Servicios reiniciados${NC}"

echo
echo -e "${GREEN}=== Configuración Completada ===${NC}"
echo
echo -e "${BLUE}Reglas aplicadas:${NC}"
$IPTABLES -L INPUT -n -v | grep -E "ACCEPT.*dpt:(22|80|443|8080|2022|3306|25565|19132|19133:20100)" | head -20

echo
echo -e "${BLUE}Verificación:${NC}"
echo "1. Ver todas las reglas:"
echo "   sudo $IPTABLES -L INPUT -n -v"
echo
echo "2. Probar puertos desde FUERA del servidor:"
echo "   nc -zv $PUBLIC_IP 25565"
echo "   nc -zv $PUBLIC_IP 19132"
echo
echo "3. Ver puertos escuchando:"
echo "   sudo ss -tulnp | grep -E '25565|19132|8080'"
echo
echo "4. Probar desde Minecraft:"
echo "   Conectar a: $PUBLIC_IP:25565"
echo
echo -e "${GREEN}✓ Los puertos deberían estar completamente abiertos ahora${NC}"
echo -e "${YELLOW}⚠ NOTA: La protección DDoS está DESACTIVADA en estos puertos para máxima compatibilidad${NC}"
