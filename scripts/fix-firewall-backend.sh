#!/bin/bash

# Script para corregir el backend de iptables y configurar correctamente el firewall
# Soluciona el problema de nf_tables vs iptables-legacy

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Corrección de Backend de Firewall ===${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
    exit 1
fi

# Detener servicios
echo -e "${YELLOW}[1/8] Deteniendo servicios Anti-DDoS...${NC}"
systemctl stop antiddos-monitor 2>/dev/null
systemctl stop antiddos-ssh 2>/dev/null
systemctl stop antiddos-xcord 2>/dev/null
echo -e "${GREEN}✓ Servicios detenidos${NC}"

# Limpiar reglas existentes
echo -e "${YELLOW}[2/8] Limpiando reglas existentes...${NC}"
iptables -D INPUT -j ANTIDDOS 2>/dev/null
iptables -F ANTIDDOS 2>/dev/null
iptables -X ANTIDDOS 2>/dev/null
iptables-legacy -D INPUT -j ANTIDDOS 2>/dev/null
iptables-legacy -F ANTIDDOS 2>/dev/null
iptables-legacy -X ANTIDDOS 2>/dev/null
echo -e "${GREEN}✓ Reglas limpiadas${NC}"

# Configurar alternativas de iptables
echo -e "${YELLOW}[3/8] Configurando alternativas de iptables...${NC}"
if command -v update-alternatives &> /dev/null; then
    update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || true
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || true
    echo -e "${GREEN}✓ Alternativas configuradas para usar iptables-legacy${NC}"
else
    echo -e "${YELLOW}! update-alternatives no disponible, continuando...${NC}"
fi

# Crear enlaces simbólicos si es necesario
echo -e "${YELLOW}[4/8] Verificando enlaces simbólicos...${NC}"
if [ -f /usr/sbin/iptables-legacy ]; then
    echo -e "${GREEN}✓ iptables-legacy disponible${NC}"
else
    echo -e "${RED}✗ iptables-legacy no encontrado${NC}"
    echo "Instalando iptables..."
    apt-get update && apt-get install -y iptables
fi

# Modificar el código Python para usar iptables-legacy
echo -e "${YELLOW}[5/8] Actualizando código para usar iptables-legacy...${NC}"

# Buscar archivos Python del proyecto
PYTHON_SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])")
FIREWALL_PY="$PYTHON_SITE_PACKAGES/antiddos/firewall.py"

if [ -f "$FIREWALL_PY" ]; then
    # Hacer backup
    cp "$FIREWALL_PY" "$FIREWALL_PY.backup"
    
    # Reemplazar 'iptables' con 'iptables-legacy'
    sed -i 's/\["iptables"/["iptables-legacy"/g' "$FIREWALL_PY"
    sed -i "s/'iptables'/'iptables-legacy'/g" "$FIREWALL_PY"
    
    echo -e "${GREEN}✓ Código actualizado para usar iptables-legacy${NC}"
else
    echo -e "${YELLOW}! Archivo firewall.py no encontrado en: $FIREWALL_PY${NC}"
fi

# Crear configuración de módulos
echo -e "${YELLOW}[6/8] Configurando módulos del kernel...${NC}"
cat > /etc/modprobe.d/iptables.conf << 'EOF'
# Usar iptables legacy en lugar de nf_tables
blacklist nf_tables
blacklist nft_chain_nat
EOF

# Cargar módulos necesarios
modprobe ip_tables 2>/dev/null || true
modprobe iptable_filter 2>/dev/null || true
modprobe iptable_nat 2>/dev/null || true

echo -e "${GREEN}✓ Módulos configurados${NC}"

# Crear cadena ANTIDDOS manualmente
echo -e "${YELLOW}[7/8] Creando cadena ANTIDDOS...${NC}"
iptables-legacy -N ANTIDDOS 2>/dev/null || echo "Cadena ya existe"
iptables-legacy -I INPUT 1 -j ANTIDDOS 2>/dev/null || echo "Regla ya existe"

# Agregar reglas básicas
iptables-legacy -A ANTIDDOS -i lo -j ACCEPT
iptables-legacy -A ANTIDDOS -m state --state ESTABLISHED,RELATED -j ACCEPT

# Permitir IP del servidor
iptables-legacy -I ANTIDDOS 1 -s 190.57.138.18 -j ACCEPT

echo -e "${GREEN}✓ Cadena ANTIDDOS creada${NC}"

# Guardar reglas
echo -e "${YELLOW}[8/8] Guardando reglas...${NC}"
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save
    echo -e "${GREEN}✓ Reglas guardadas${NC}"
else
    echo -e "${YELLOW}! netfilter-persistent no disponible${NC}"
fi

echo
echo -e "${GREEN}=== Corrección Completada ===${NC}"
echo
echo -e "${BLUE}Verificación:${NC}"
iptables-legacy -L ANTIDDOS -n 2>/dev/null && echo -e "${GREEN}✓ Cadena ANTIDDOS existe${NC}" || echo -e "${RED}✗ Error: Cadena no existe${NC}"

echo
echo -e "${YELLOW}Ahora puedes:${NC}"
echo "1. Iniciar servicios:"
echo "   sudo systemctl start antiddos-monitor"
echo
echo "2. Desbloquear MariaDB:"
echo "   sudo /opt/anti-ddos/scripts/unlock-mariadb-for-ip.sh"
echo
echo "3. Ver logs:"
echo "   sudo journalctl -u antiddos-monitor -f"
