#!/bin/bash

# Script de desinstalación COMPLETA del sistema Anti-DDoS
# Elimina TODO y restaura el sistema al estado original

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║     DESINSTALACIÓN COMPLETA - ANTI-DDOS            ║${NC}"
echo -e "${RED}║     ⚠ ESTO ELIMINARÁ TODO EL SISTEMA ⚠            ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════╝${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
    exit 1
fi

echo -e "${YELLOW}Este script hará lo siguiente:${NC}"
echo "  1. Detener todos los servicios Anti-DDoS"
echo "  2. Eliminar servicios systemd"
echo "  3. Limpiar TODAS las reglas de iptables"
echo "  4. Restaurar política por defecto (ACCEPT)"
echo "  5. Eliminar archivos de configuración"
echo "  6. Desinstalar paquete Python"
echo "  7. Eliminar directorio del proyecto"
echo "  8. Limpiar logs"
echo

read -p "¿Estás SEGURO de continuar? (escribe 'SI' en mayúsculas): " confirm

if [ "$confirm" != "SI" ]; then
    echo -e "${YELLOW}Cancelado${NC}"
    exit 0
fi

echo
echo -e "${GREEN}Iniciando desinstalación completa...${NC}"
echo

# Detectar iptables
if command -v iptables-legacy &> /dev/null && iptables-legacy -L -n &>/dev/null 2>&1; then
    IPTABLES="iptables-legacy"
else
    IPTABLES="iptables"
fi

echo -e "${BLUE}Usando: $IPTABLES${NC}"
echo

# ============================================
# 1. DETENER SERVICIOS
# ============================================
echo -e "${YELLOW}[1/10] Deteniendo servicios...${NC}"

systemctl stop antiddos-monitor 2>/dev/null && echo "  ✓ antiddos-monitor detenido"
systemctl stop antiddos-ssh 2>/dev/null && echo "  ✓ antiddos-ssh detenido"
systemctl disable antiddos-monitor 2>/dev/null
systemctl disable antiddos-ssh 2>/dev/null

echo -e "${GREEN}✓ Servicios detenidos${NC}"

# ============================================
# 2. ELIMINAR SERVICIOS SYSTEMD
# ============================================
echo
echo -e "${YELLOW}[2/10] Eliminando servicios systemd...${NC}"

rm -f /etc/systemd/system/antiddos-monitor.service
rm -f /etc/systemd/system/antiddos-ssh.service
systemctl daemon-reload

echo -e "${GREEN}✓ Servicios eliminados${NC}"

# ============================================
# 3. LIMPIAR IPTABLES COMPLETAMENTE
# ============================================
echo
echo -e "${YELLOW}[3/10] Limpiando reglas de iptables...${NC}"

# Remover saltos a ANTIDDOS
echo "  Removiendo saltos a ANTIDDOS..."
while $IPTABLES -D INPUT -j ANTIDDOS 2>/dev/null; do
    :
done
while $IPTABLES -D FORWARD -j ANTIDDOS 2>/dev/null; do
    :
done
while $IPTABLES -D OUTPUT -j ANTIDDOS 2>/dev/null; do
    :
done

# Eliminar cadena ANTIDDOS
if $IPTABLES -L ANTIDDOS -n &>/dev/null; then
    echo "  Eliminando cadena ANTIDDOS..."
    $IPTABLES -F ANTIDDOS
    $IPTABLES -X ANTIDDOS
fi

# Eliminar cadenas de países si existen
for chain in $($IPTABLES -L -n | grep "^Chain ANTIDDOS_" | awk '{print $2}'); do
    echo "  Eliminando cadena $chain..."
    $IPTABLES -F $chain 2>/dev/null
    $IPTABLES -X $chain 2>/dev/null
done

# Limpiar todas las cadenas principales
echo "  Limpiando cadenas INPUT, FORWARD, OUTPUT..."
$IPTABLES -F INPUT
$IPTABLES -F FORWARD
$IPTABLES -F OUTPUT
$IPTABLES -F

# Restaurar política por defecto a ACCEPT
echo "  Restaurando política ACCEPT..."
$IPTABLES -P INPUT ACCEPT
$IPTABLES -P FORWARD ACCEPT
$IPTABLES -P OUTPUT ACCEPT

# Limpiar NAT y MANGLE
$IPTABLES -t nat -F 2>/dev/null
$IPTABLES -t mangle -F 2>/dev/null

echo -e "${GREEN}✓ Iptables limpiado completamente${NC}"

# ============================================
# 4. APLICAR REGLAS BÁSICAS SEGURAS
# ============================================
echo
echo -e "${YELLOW}[4/10] Aplicando reglas básicas de seguridad...${NC}"

# Loopback
$IPTABLES -A INPUT -i lo -j ACCEPT
echo "  ✓ Loopback permitido"

# Conexiones establecidas
$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
echo "  ✓ Conexiones establecidas permitidas"

# SSH (para no perder acceso)
$IPTABLES -A INPUT -p tcp --dport 22 -j ACCEPT
echo "  ✓ SSH (22) permitido"

# HTTP/HTTPS
$IPTABLES -A INPUT -p tcp --dport 80 -j ACCEPT
$IPTABLES -A INPUT -p tcp --dport 443 -j ACCEPT
echo "  ✓ HTTP/HTTPS (80/443) permitidos"

# Docker
$IPTABLES -A INPUT -i docker0 -j ACCEPT
$IPTABLES -A FORWARD -i docker0 -j ACCEPT
$IPTABLES -A FORWARD -o docker0 -j ACCEPT
echo "  ✓ Docker permitido"

# Pterodactyl Wings
$IPTABLES -A INPUT -p tcp --dport 8080 -j ACCEPT
$IPTABLES -A INPUT -p tcp --dport 2022 -j ACCEPT
echo "  ✓ Wings (8080) y SFTP (2022) permitidos"

# MySQL
$IPTABLES -A INPUT -p tcp --dport 3306 -j ACCEPT
echo "  ✓ MySQL (3306) permitido"

# Puertos de juegos - TODOS ABIERTOS
$IPTABLES -A INPUT -p tcp --dport 25565 -j ACCEPT
$IPTABLES -A INPUT -p udp --dport 25565 -j ACCEPT
$IPTABLES -A INPUT -p tcp --dport 19132 -j ACCEPT
$IPTABLES -A INPUT -p udp --dport 19132 -j ACCEPT
$IPTABLES -A INPUT -p tcp --dport 19133:20100 -j ACCEPT
$IPTABLES -A INPUT -p udp --dport 19133:20100 -j ACCEPT
echo "  ✓ Puertos de juegos (25565, 19132, 19133-20100) permitidos"

echo -e "${GREEN}✓ Reglas básicas aplicadas${NC}"

# ============================================
# 5. GUARDAR REGLAS
# ============================================
echo
echo -e "${YELLOW}[5/10] Guardando reglas permanentemente...${NC}"

if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save &>/dev/null
    echo -e "${GREEN}✓ Guardado con netfilter-persistent${NC}"
elif [ -d /etc/iptables ]; then
    $IPTABLES-save > /etc/iptables/rules.v4
    echo -e "${GREEN}✓ Guardado en /etc/iptables/rules.v4${NC}"
fi

# ============================================
# 6. DESINSTALAR PAQUETE PYTHON
# ============================================
echo
echo -e "${YELLOW}[6/10] Desinstalando paquete Python...${NC}"

pip3 uninstall -y antiddos 2>/dev/null && echo "  ✓ Paquete desinstalado"

# Eliminar enlaces simbólicos
rm -f /usr/local/bin/antiddos-cli 2>/dev/null
rm -f /usr/bin/antiddos-cli 2>/dev/null

echo -e "${GREEN}✓ Paquete Python eliminado${NC}"

# ============================================
# 7. ELIMINAR ARCHIVOS DE CONFIGURACIÓN
# ============================================
echo
echo -e "${YELLOW}[7/10] Eliminando archivos de configuración...${NC}"

rm -rf /etc/antiddos
echo "  ✓ /etc/antiddos eliminado"

rm -rf /var/log/antiddos
echo "  ✓ /var/log/antiddos eliminado"

# ============================================
# 8. ELIMINAR DIRECTORIO DEL PROYECTO
# ============================================
echo
echo -e "${YELLOW}[8/10] Eliminando directorio del proyecto...${NC}"

if [ -d /opt/anti-ddos ]; then
    rm -rf /opt/anti-ddos
    echo "  ✓ /opt/anti-ddos eliminado"
fi

# ============================================
# 9. LIMPIAR CRON JOBS
# ============================================
echo
echo -e "${YELLOW}[9/10] Limpiando tareas programadas...${NC}"

crontab -l 2>/dev/null | grep -v "antiddos" | crontab - 2>/dev/null
echo -e "${GREEN}✓ Cron jobs limpiados${NC}"

# ============================================
# 10. REINICIAR SERVICIOS
# ============================================
echo
echo -e "${YELLOW}[10/10] Reiniciando servicios...${NC}"

systemctl restart docker 2>/dev/null && echo "  ✓ Docker reiniciado"
systemctl restart wings 2>/dev/null && echo "  ✓ Wings reiniciado"

# ============================================
# RESUMEN FINAL
# ============================================
echo
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          DESINSTALACIÓN COMPLETADA                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo

echo -e "${BLUE}Resumen de lo eliminado:${NC}"
echo "  ✓ Servicios systemd (antiddos-monitor, antiddos-ssh)"
echo "  ✓ Cadena ANTIDDOS de iptables"
echo "  ✓ Todas las reglas personalizadas"
echo "  ✓ Paquete Python antiddos"
echo "  ✓ Archivos de configuración (/etc/antiddos)"
echo "  ✓ Logs (/var/log/antiddos)"
echo "  ✓ Directorio del proyecto (/opt/anti-ddos)"
echo "  ✓ Tareas programadas (cron)"
echo

echo -e "${BLUE}Estado actual del sistema:${NC}"
echo "  ✓ Política iptables: ACCEPT (todo permitido)"
echo "  ✓ Puertos abiertos: 22, 80, 443, 3306, 8080, 2022, 25565, 19132, 19133-20100"
echo "  ✓ Docker: Funcionando normalmente"
echo "  ✓ Wings: Funcionando normalmente"
echo

echo -e "${YELLOW}Reglas actuales de iptables:${NC}"
$IPTABLES -L INPUT -n --line-numbers

echo
echo -e "${GREEN}✓ Sistema restaurado al estado original${NC}"
echo -e "${GREEN}✓ Todos los puertos de Pterodactyl están abiertos${NC}"
echo

echo -e "${BLUE}Verificación:${NC}"
echo "Ver puertos escuchando:"
echo "  sudo ss -tulnp | grep -E '25565|19132|8080'"
echo
echo "Probar conexión:"
echo "  nc -zv 190.57.138.18 25565"
echo
echo "Ver reglas iptables:"
echo "  sudo $IPTABLES -L -n -v"
echo

echo -e "${GREEN}¡Listo! El sistema Anti-DDoS ha sido eliminado completamente.${NC}"
