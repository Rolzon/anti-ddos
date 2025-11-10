#!/bin/bash

# Script de diagnóstico de puertos
# Verifica por qué los puertos aparecen cerrados

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Diagnóstico de Puertos Pterodactyl ===${NC}"
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

# Puertos a verificar
PORTS_TO_CHECK=(
    "8080:tcp:Wings"
    "2022:tcp:SFTP"
    "25565:tcp:Minecraft-Java"
    "19132:udp:Minecraft-Bedrock"
    "19150:tcp:Pterodactyl-Server"
)

echo -e "${YELLOW}[1/6] Verificando si los puertos están escuchando...${NC}"
echo
for port_info in "${PORTS_TO_CHECK[@]}"; do
    IFS=':' read -r port proto name <<< "$port_info"
    echo -n "  Puerto $port ($name): "
    
    if ss -tlnp 2>/dev/null | grep -q ":$port " || ss -ulnp 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}✓ ESCUCHANDO${NC}"
    else
        echo -e "${RED}✗ NO ESCUCHANDO${NC}"
    fi
done

echo
echo -e "${YELLOW}[2/6] Verificando reglas en cadena INPUT...${NC}"
echo
$IPTABLES -L INPUT -n -v --line-numbers | head -20

echo
echo -e "${YELLOW}[3/6] Verificando reglas en cadena ANTIDDOS...${NC}"
echo
if $IPTABLES -L ANTIDDOS -n &>/dev/null; then
    $IPTABLES -L ANTIDDOS -n -v --line-numbers | head -30
else
    echo -e "${RED}✗ Cadena ANTIDDOS no existe${NC}"
fi

echo
echo -e "${YELLOW}[4/6] Verificando orden de reglas (CRÍTICO)...${NC}"
echo
echo "Primeras 10 reglas de INPUT:"
$IPTABLES -L INPUT -n --line-numbers | head -15

echo
echo "Buscando salto a ANTIDDOS:"
$IPTABLES -L INPUT -n --line-numbers | grep ANTIDDOS

echo
echo -e "${YELLOW}[5/6] Verificando política por defecto...${NC}"
echo
$IPTABLES -L INPUT -n | grep "Chain INPUT"
$IPTABLES -L FORWARD -n | grep "Chain FORWARD"

echo
echo -e "${YELLOW}[6/6] Probando conectividad externa...${NC}"
echo
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null)
echo "IP pública del servidor: $SERVER_IP"
echo

# Análisis del problema
echo
echo -e "${BLUE}=== ANÁLISIS ===${NC}"
echo

# Verificar si ANTIDDOS está antes de las reglas ACCEPT
ANTIDDOS_LINE=$($IPTABLES -L INPUT -n --line-numbers | grep "ANTIDDOS" | head -1 | awk '{print $1}')
ACCEPT_LINE=$($IPTABLES -L INPUT -n --line-numbers | grep "ACCEPT" | grep -E "25565|19132|8080" | head -1 | awk '{print $1}')

if [ -n "$ANTIDDOS_LINE" ] && [ -n "$ACCEPT_LINE" ]; then
    if [ "$ANTIDDOS_LINE" -lt "$ACCEPT_LINE" ]; then
        echo -e "${RED}⚠ PROBLEMA ENCONTRADO:${NC}"
        echo "  La cadena ANTIDDOS (línea $ANTIDDOS_LINE) está ANTES de las reglas ACCEPT (línea $ACCEPT_LINE)"
        echo "  Esto significa que el tráfico pasa por ANTIDDOS primero y puede ser bloqueado"
        echo
        echo -e "${YELLOW}SOLUCIÓN:${NC}"
        echo "  Las reglas ACCEPT deben estar ANTES del salto a ANTIDDOS"
        NEEDS_FIX=true
    else
        echo -e "${GREEN}✓ Orden de reglas correcto${NC}"
        NEEDS_FIX=false
    fi
fi

# Verificar política por defecto
DEFAULT_POLICY=$($IPTABLES -L INPUT -n | grep "Chain INPUT" | awk '{print $4}' | tr -d ')')
if [ "$DEFAULT_POLICY" = "DROP" ] || [ "$DEFAULT_POLICY" = "REJECT" ]; then
    echo -e "${YELLOW}⚠ Política por defecto de INPUT: $DEFAULT_POLICY${NC}"
    echo "  Esto bloqueará todo el tráfico que no coincida con una regla ACCEPT"
fi

echo
echo -e "${BLUE}=== RECOMENDACIONES ===${NC}"
echo

if [ "$NEEDS_FIX" = true ]; then
    echo "1. Ejecutar script de corrección automática"
    echo "2. Reorganizar reglas para poner ACCEPT antes de ANTIDDOS"
    echo
    echo "¿Quieres que corrija esto automáticamente? (s/n): "
    read -r response
    
    if [[ "$response" =~ ^[SsYy]$ ]]; then
        echo
        echo -e "${YELLOW}Aplicando corrección...${NC}"
        
        # Remover salto a ANTIDDOS de INPUT
        while $IPTABLES -D INPUT -j ANTIDDOS 2>/dev/null; do
            echo "  Removiendo salto a ANTIDDOS..."
        done
        
        # Agregar reglas ACCEPT primero
        echo "  Agregando reglas ACCEPT..."
        
        # Docker
        $IPTABLES -I INPUT 1 -i docker0 -j ACCEPT
        
        # Puertos Pterodactyl
        $IPTABLES -I INPUT 1 -p tcp --dport 8080 -j ACCEPT
        $IPTABLES -I INPUT 1 -p tcp --dport 2022 -j ACCEPT
        $IPTABLES -I INPUT 1 -p tcp --dport 25565 -j ACCEPT
        $IPTABLES -I INPUT 1 -p udp --dport 25565 -j ACCEPT
        $IPTABLES -I INPUT 1 -p tcp --dport 19132 -j ACCEPT
        $IPTABLES -I INPUT 1 -p udp --dport 19132 -j ACCEPT
        $IPTABLES -I INPUT 1 -p tcp --dport 19133:20100 -j ACCEPT
        $IPTABLES -I INPUT 1 -p udp --dport 19133:20100 -j ACCEPT
        
        # Localhost
        $IPTABLES -I INPUT 1 -i lo -j ACCEPT
        
        # Conexiones establecidas
        $IPTABLES -I INPUT 1 -m state --state ESTABLISHED,RELATED -j ACCEPT
        
        # Ahora agregar salto a ANTIDDOS al final
        $IPTABLES -A INPUT -j ANTIDDOS
        
        echo
        echo -e "${GREEN}✓ Corrección aplicada${NC}"
        echo
        echo "Nuevas primeras 15 reglas de INPUT:"
        $IPTABLES -L INPUT -n --line-numbers | head -20
        
        # Guardar
        if command -v netfilter-persistent &> /dev/null; then
            netfilter-persistent save &>/dev/null
            echo -e "${GREEN}✓ Reglas guardadas${NC}"
        fi
        
        echo
        echo -e "${GREEN}Ahora prueba conectar a los servidores${NC}"
    fi
else
    echo "Verificar:"
    echo "1. ¿Los servicios están corriendo? (docker ps)"
    echo "2. ¿Wings está activo? (systemctl status wings)"
    echo "3. ¿Los puertos están asignados en Pterodactyl?"
    echo "4. ¿Hay un firewall externo (UFW, firewalld)?"
fi

echo
echo -e "${BLUE}Comandos útiles:${NC}"
echo "Ver todas las reglas: sudo $IPTABLES -L -n -v --line-numbers"
echo "Ver puertos escuchando: sudo ss -tulnp"
echo "Probar puerto: nc -zv IP PUERTO"
echo "Ver logs Wings: sudo journalctl -u wings -f"
