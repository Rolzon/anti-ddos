#!/bin/bash

# Script para abrir y proteger el puerto 3306 (MySQL/MariaDB)
# Este script configura reglas de iptables para permitir conexiones MySQL
# mientras mantiene protección contra ataques

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Configuración Puerto MySQL 3306 ===${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
    exit 1
fi

# Detectar si usa iptables-legacy o iptables-nft
echo -e "${YELLOW}Detectando sistema de firewall...${NC}"
if command -v iptables-legacy &> /dev/null; then
    # Probar iptables-legacy primero
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

# Verificar que la cadena ANTIDDOS existe
if ! $IPTABLES -L ANTIDDOS -n &>/dev/null; then
    echo -e "${RED}Error: La cadena ANTIDDOS no existe${NC}"
    echo "Ejecuta primero: sudo systemctl start antiddos-monitor"
    exit 1
fi

echo -e "${YELLOW}[1/4] Configurando acceso al puerto 3306...${NC}"

# Permitir conexiones establecidas
$IPTABLES -I ANTIDDOS -p tcp --dport 3306 -m state --state ESTABLISHED,RELATED -j ACCEPT

# Limitar nuevas conexiones por IP (protección contra ataques)
$IPTABLES -I ANTIDDOS -p tcp --dport 3306 -m connlimit --connlimit-above 10 -j REJECT --reject-with tcp-reset

# Rate limit para nuevas conexiones
$IPTABLES -I ANTIDDOS -p tcp --dport 3306 --syn -m limit --limit 10/s --limit-burst 20 -j ACCEPT

# Permitir conexiones desde localhost sin límites
$IPTABLES -I ANTIDDOS -s 127.0.0.1 -p tcp --dport 3306 -j ACCEPT
$IPTABLES -I ANTIDDOS -s ::1 -p tcp --dport 3306 -j ACCEPT

echo -e "${GREEN}✓ Puerto 3306 configurado${NC}"

echo -e "${YELLOW}[2/4] Aplicando protecciones adicionales...${NC}"

# Protección contra SYN flood específica para MySQL
$IPTABLES -I ANTIDDOS -p tcp --dport 3306 --syn -m recent --name mysql_syn --set
$IPTABLES -I ANTIDDOS -p tcp --dport 3306 --syn -m recent --name mysql_syn --update --seconds 1 --hitcount 5 -j DROP

# Bloquear paquetes inválidos
$IPTABLES -I ANTIDDOS -p tcp --dport 3306 -m state --state INVALID -j DROP

echo -e "${GREEN}✓ Protecciones aplicadas${NC}"

echo -e "${YELLOW}[3/4] Configurando IPs de confianza...${NC}"

# Permitir IP pública del servidor (para conexiones locales)
SERVER_PUBLIC_IP="190.57.138.18"
$IPTABLES -I ANTIDDOS -s "$SERVER_PUBLIC_IP" -p tcp --dport 3306 -j ACCEPT
echo -e "${GREEN}  ✓ Permitido desde IP pública del servidor: $SERVER_PUBLIC_IP${NC}"

# Leer IPs de la whitelist si existe
if [ -f /etc/antiddos/whitelist.txt ]; then
    while IFS= read -r ip; do
        # Saltar líneas vacías y comentarios
        [[ -z "$ip" || "$ip" =~ ^# ]] && continue
        
        # Permitir acceso completo desde IPs en whitelist
        $IPTABLES -I ANTIDDOS -s "$ip" -p tcp --dport 3306 -j ACCEPT
        echo "  ✓ Permitido desde: $ip"
    done < /etc/antiddos/whitelist.txt
else
    echo -e "${YELLOW}  ! No se encontró whitelist, considera agregar IPs de confianza${NC}"
fi

echo -e "${YELLOW}[4/4] Guardando reglas...${NC}"

# Guardar reglas de iptables
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save
    echo -e "${GREEN}✓ Reglas guardadas con netfilter-persistent${NC}"
elif command -v iptables-save &> /dev/null; then
    iptables-save > /etc/iptables/rules.v4
    echo -e "${GREEN}✓ Reglas guardadas en /etc/iptables/rules.v4${NC}"
else
    echo -e "${YELLOW}! No se pudo guardar automáticamente. Guarda manualmente con: iptables-save${NC}"
fi

echo
echo -e "${GREEN}=== Configuración Completada ===${NC}"
echo
echo "Puerto 3306 (MySQL) está ahora:"
echo "  ✓ Abierto para conexiones"
echo "  ✓ Protegido contra ataques"
echo "  ✓ Con límite de 10 conexiones por IP"
echo "  ✓ Rate limit de 10 conexiones/segundo"
echo
echo "Reglas aplicadas:"
$IPTABLES -L ANTIDDOS -n -v | grep 3306
echo
echo -e "${YELLOW}Recomendaciones de seguridad:${NC}"
echo "1. Agrega las IPs de tus aplicaciones a la whitelist:"
echo "   sudo antiddos-cli whitelist add IP_DE_TU_APP"
echo
echo "2. Configura MySQL para escuchar solo en IPs específicas:"
echo "   sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf"
echo "   bind-address = 0.0.0.0  # O una IP específica"
echo
echo "3. Usa autenticación fuerte en MySQL"
echo
echo "4. Considera usar SSL/TLS para conexiones MySQL"
echo
echo "Para verificar conexiones activas:"
echo "  sudo ss -tnp | grep :3306"
echo
echo "Para ver estadísticas del puerto:"
echo "  sudo $IPTABLES -L ANTIDDOS -n -v | grep 3306"
