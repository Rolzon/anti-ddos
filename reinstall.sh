#!/bin/bash
set -e

echo "================================================"
echo "  Anti-DDoS - Reinstalación Completa"
echo "================================================"
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script debe ejecutarse como root (sudo)${NC}" 
   exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo -e "${GREEN}Directorio del proyecto: ${PROJECT_DIR}${NC}"
echo ""

# 1. DETENER Y LIMPIAR INSTALACIÓN ANTERIOR
echo -e "${YELLOW}[1/6] Deteniendo servicio anterior...${NC}"
systemctl stop antiddos-monitor.service 2>/dev/null || true
systemctl disable antiddos-monitor.service 2>/dev/null || true
rm -f /etc/systemd/system/antiddos-monitor.service
systemctl daemon-reload
echo -e "${GREEN}✓ Servicio anterior limpiado${NC}"
echo ""

# 2. INSTALAR DEPENDENCIAS DEL SISTEMA
echo -e "${YELLOW}[2/6] Instalando dependencias del sistema...${NC}"
apt update -qq
apt install -y iptables nftables python3-pip python3-venv net-tools psmisc
echo -e "${GREEN}✓ Dependencias instaladas${NC}"
echo ""

# 3. CONFIGURAR IPTABLES-NFT
echo -e "${YELLOW}[3/6] Configurando iptables-nft...${NC}"
update-alternatives --set iptables /usr/sbin/iptables-nft 2>/dev/null || true
update-alternatives --set ip6tables /usr/sbin/ip6tables-nft 2>/dev/null || true
echo -e "${GREEN}✓ iptables-nft configurado${NC}"
echo ""

# 4. INSTALAR PROYECTO PYTHON
echo -e "${YELLOW}[4/6] Instalando proyecto Anti-DDoS...${NC}"
cd "$PROJECT_DIR"
pip3 uninstall antiddos -y 2>/dev/null || true
pip3 install -e .
echo -e "${GREEN}✓ Proyecto instalado${NC}"
echo ""

# 5. CREAR DIRECTORIOS Y PERMISOS
echo -e "${YELLOW}[5/6] Configurando directorios y permisos...${NC}"
mkdir -p /etc/antiddos
mkdir -p /var/log/antiddos
mkdir -p /var/lib/antiddos

# Copiar configuración si no existe
if [ ! -f /etc/antiddos/config.yaml ]; then
    cp "$PROJECT_DIR/config/config.yaml" /etc/antiddos/config.yaml
    echo -e "${GREEN}✓ Configuración copiada a /etc/antiddos/config.yaml${NC}"
else
    echo -e "${YELLOW}⚠ Configuración existente preservada en /etc/antiddos/config.yaml${NC}"
fi

# Crear archivos de blacklist/whitelist si no existen
touch /etc/antiddos/blacklist.txt
touch /etc/antiddos/whitelist.txt

# Permisos
chmod 755 /etc/antiddos
chmod 644 /etc/antiddos/config.yaml
chmod 644 /etc/antiddos/blacklist.txt
chmod 644 /etc/antiddos/whitelist.txt
chmod 755 /var/log/antiddos
chmod 755 /var/lib/antiddos

echo -e "${GREEN}✓ Directorios y permisos configurados${NC}"
echo ""

# 6. INSTALAR SERVICIO SYSTEMD
echo -e "${YELLOW}[6/6] Instalando servicio systemd...${NC}"

cat > /etc/systemd/system/antiddos-monitor.service <<'EOF'
[Unit]
Description=Anti-DDoS Monitor Service
After=network.target docker.service
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/usr/local/bin/antiddos monitor
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=antiddos

# Capacidades necesarias para iptables
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW

[Install]
WantedBy=multi-user.target
EOF

# Recargar systemd
systemctl daemon-reload
echo -e "${GREEN}✓ Servicio systemd instalado${NC}"
echo ""

# RESUMEN
echo "================================================"
echo -e "${GREEN}✓ Instalación completada exitosamente${NC}"
echo "================================================"
echo ""
echo "Comandos útiles:"
echo "  - Iniciar servicio:    sudo systemctl start antiddos-monitor"
echo "  - Habilitar al inicio: sudo systemctl enable antiddos-monitor"
echo "  - Ver estado:          sudo systemctl status antiddos-monitor"
echo "  - Ver logs:            sudo journalctl -u antiddos-monitor -f"
echo "  - Ver configuración:   antiddos status"
echo ""
echo "Archivos importantes:"
echo "  - Config:     /etc/antiddos/config.yaml"
echo "  - Blacklist:  /etc/antiddos/blacklist.txt"
echo "  - Whitelist:  /etc/antiddos/whitelist.txt"
echo "  - Logs:       /var/log/antiddos/"
echo ""
echo -e "${YELLOW}Siguiente paso:${NC} Edita /etc/antiddos/config.yaml si es necesario"
echo "y luego ejecuta: sudo systemctl start antiddos-monitor"
echo ""
