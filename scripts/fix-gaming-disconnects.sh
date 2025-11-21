#!/bin/bash

# Script para solucionar desconexiones de jugadores en Pterodactyl
# Este script elimina TODAS las reglas ANTIDDOS que puedan estar bloqueando tráfico

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}=== Reparación de Desconexiones Gaming ===${NC}"
echo -e "${YELLOW}Este script eliminará TODAS las reglas ANTIDDOS que puedan estar bloqueando jugadores${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
    exit 1
fi

# Detectar iptables
if command -v iptables-nft &> /dev/null && iptables-nft -L -n &>/dev/null 2>&1; then
    IPTABLES="iptables-nft"
else
    IPTABLES="iptables"
fi

echo -e "${YELLOW}[1/7] Detectando sistema de firewall...${NC}"
echo "  Usando: $IPTABLES"

# Paso 1: Detener servicio ANTIDDOS
echo
echo -e "${YELLOW}[2/7] Deteniendo servicios Anti-DDoS...${NC}"
systemctl stop antiddos-monitor 2>/dev/null && echo "  ✓ antiddos-monitor detenido"
systemctl stop antiddos-ssh 2>/dev/null && echo "  ✓ antiddos-ssh detenido"
sleep 2

# Paso 2: Eliminar TODOS los saltos a cadenas ANTIDDOS
echo
echo -e "${YELLOW}[3/7] Eliminando saltos a cadenas ANTIDDOS...${NC}"

# Eliminar de INPUT
removed=0
while $IPTABLES -D INPUT -j ANTIDDOS 2>/dev/null; do
    removed=$((removed + 1))
    echo "  ✓ Removido salto de INPUT (#$removed)"
done

# Eliminar de FORWARD
removed=0
while $IPTABLES -D FORWARD -j ANTIDDOS 2>/dev/null; do
    removed=$((removed + 1))
    echo "  ✓ Removido salto de FORWARD (#$removed)"
done

# Eliminar de OUTPUT (por si acaso)
removed=0
while $IPTABLES -D OUTPUT -j ANTIDDOS 2>/dev/null; do
    removed=$((removed + 1))
    echo "  ✓ Removido salto de OUTPUT (#$removed)"
done

# Paso 3: Limpiar y eliminar TODAS las cadenas ANTIDDOS
echo
echo -e "${YELLOW}[4/7] Eliminando cadenas ANTIDDOS...${NC}"

# Obtener lista de todas las cadenas ANTIDDOS
chains=$($IPTABLES -L -n | grep "Chain ANTIDDOS" | awk '{print $2}')

if [ -z "$chains" ]; then
    echo "  ℹ No se encontraron cadenas ANTIDDOS"
else
    for chain in $chains; do
        echo "  Limpiando: $chain"
        $IPTABLES -F "$chain" 2>/dev/null
        $IPTABLES -X "$chain" 2>/dev/null
        echo "  ✓ $chain eliminada"
    done
fi

# Paso 4: Verificar que Docker sigue funcionando
echo
echo -e "${YELLOW}[5/7] Verificando cadenas Docker...${NC}"

if $IPTABLES -t nat -L DOCKER -n &>/dev/null; then
    echo -e "  ${GREEN}✓ Cadena DOCKER NAT: OK${NC}"
else
    echo -e "  ${RED}✗ Cadena DOCKER NAT: NO ENCONTRADA${NC}"
    echo "  Reiniciando Docker..."
    systemctl restart docker
    sleep 3
fi

if $IPTABLES -L DOCKER -n &>/dev/null; then
    echo -e "  ${GREEN}✓ Cadena DOCKER filter: OK${NC}"
else
    echo -e "  ${RED}✗ Cadena DOCKER filter: NO ENCONTRADA${NC}"
fi

# Paso 5: Asegurar que el tráfico está permitido
echo
echo -e "${YELLOW}[6/7] Asegurando reglas mínimas para gaming...${NC}"

# Loopback
$IPTABLES -C INPUT -i lo -j ACCEPT 2>/dev/null || {
    $IPTABLES -I INPUT 1 -i lo -j ACCEPT
    echo "  ✓ Loopback permitido"
}

# Conexiones establecidas
$IPTABLES -C INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || {
    $IPTABLES -I INPUT 1 -m state --state ESTABLISHED,RELATED -j ACCEPT
    echo "  ✓ Conexiones establecidas permitidas"
}

# Docker
$IPTABLES -C INPUT -i docker0 -j ACCEPT 2>/dev/null || {
    $IPTABLES -I INPUT 1 -i docker0 -j ACCEPT
    echo "  ✓ Docker interface permitida"
}

# Verificar política
current_policy=$($IPTABLES -L INPUT -n | grep "^Chain INPUT" | awk '{print $4}' | tr -d ')')
if [ "$current_policy" != "ACCEPT" ]; then
    echo -e "  ${YELLOW}! Política INPUT es: $current_policy${NC}"
    echo "  Nota: Esto es normal si tienes otras reglas de firewall"
fi

# Paso 6: Diagnóstico de puertos
echo
echo -e "${YELLOW}[7/7] Diagnóstico de puertos gaming...${NC}"

# Ver qué puertos están escuchando
gaming_ports=$(ss -tulnp | grep -E ":(25565|19132|19133)" | wc -l)
if [ $gaming_ports -gt 0 ]; then
    echo -e "  ${GREEN}✓ $gaming_ports puertos gaming detectados${NC}"
    ss -tulnp | grep -E ":(25565|19132|19133)" | head -5 | while read line; do
        echo "    $line"
    done
else
    echo -e "  ${YELLOW}! No se detectaron puertos gaming escuchando${NC}"
    echo "  ¿Los servidores están iniciados en Pterodactyl?"
fi

# Verificar reglas NAT de Docker
nat_rules=$($IPTABLES -t nat -L DOCKER -n | grep -E "dpt:(25565|19132|19133)" | wc -l)
if [ $nat_rules -gt 0 ]; then
    echo -e "  ${GREEN}✓ $nat_rules reglas NAT de Docker para gaming${NC}"
else
    echo -e "  ${YELLOW}! No se encontraron reglas NAT para gaming${NC}"
    echo "  Reiniciando Wings..."
    systemctl restart wings 2>/dev/null
fi

# Resumen
echo
echo -e "${GREEN}=== Limpieza Completada ===${NC}"
echo
echo -e "${BLUE}Estado actual:${NC}"
echo "  ✓ Servicios ANTIDDOS: DETENIDOS"
echo "  ✓ Cadenas ANTIDDOS: ELIMINADAS"
echo "  ✓ Docker: FUNCIONANDO"
echo "  ✓ Reglas mínimas: APLICADAS"
echo

echo -e "${BLUE}Reglas actuales en INPUT (primeras 15):${NC}"
$IPTABLES -L INPUT -n --line-numbers | head -20
echo

echo -e "${GREEN}=== Instrucciones ===${NC}"
echo
echo "1. ${BLUE}Prueba conectar a los servidores AHORA${NC}"
echo "   Si funciona, el problema era las reglas ANTIDDOS"
echo
echo "2. ${BLUE}Si SIGUE sin funcionar:${NC}"
echo "   a) Verifica logs de Wings:"
echo "      sudo journalctl -u wings -n 50"
echo
echo "   b) Verifica que los contenedores están corriendo:"
echo "      docker ps"
echo
echo "   c) Prueba conectar desde el servidor mismo:"
echo "      nc -zv 127.0.0.1 25565"
echo
echo "3. ${BLUE}Para reactivar ANTIDDOS (SOLO si los jugadores pueden conectar):${NC}"
echo "   a) Primero actualiza el código:"
echo "      cd /opt/anti-ddos"
echo "      sudo git pull"
echo "      sudo pip3 install -e . --force-reinstall"
echo
echo "   b) Luego inicia el servicio:"
echo "      sudo systemctl start antiddos-monitor"
echo
echo "4. ${BLUE}Monitorear que no vuelva a pasar:${NC}"
echo "   sudo journalctl -u antiddos-monitor -f"
echo

echo -e "${YELLOW}⚠ IMPORTANTE:${NC}"
echo "Si el problema persiste con ANTIDDOS desactivado,"
echo "entonces NO es el firewall, puede ser:"
echo "  - Configuración de Wings incorrecta"
echo "  - Problema de red/ISP"
echo "  - Configuración del servidor de juego"
echo

echo -e "${GREEN}✓ Script completado${NC}"
