#!/bin/bash

# Actualización rápida a v1.0.1
# Uso: sudo bash quick-update.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Actualización Rápida a v1.0.1 ===${NC}"
echo

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Ejecutar como root${NC}"
    exit 1
fi

# Backup config
echo -e "${YELLOW}[1/5] Backup de configuración...${NC}"
BACKUP_DIR="/tmp/antiddos-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r /etc/antiddos/* "$BACKUP_DIR/" 2>/dev/null || true
echo -e "${GREEN}✓ Backup en: $BACKUP_DIR${NC}"

# Stop services
echo -e "${YELLOW}[2/5] Deteniendo servicios...${NC}"
systemctl stop antiddos-monitor antiddos-ssh antiddos-xcord 2>/dev/null || true
echo -e "${GREEN}✓ Servicios detenidos${NC}"

# Update code
echo -e "${YELLOW}[3/5] Actualizando código...${NC}"
git fetch origin
git reset --hard origin/main
echo -e "${GREEN}✓ Código actualizado${NC}"

# Update Python package
echo -e "${YELLOW}[4/5] Actualizando paquete...${NC}"
pip3 install -e . --upgrade
echo -e "${GREEN}✓ Paquete actualizado${NC}"

# Restore config and restart
echo -e "${YELLOW}[5/5] Restaurando y reiniciando...${NC}"
cp "$BACKUP_DIR"/* /etc/antiddos/ 2>/dev/null || true
systemctl daemon-reload
systemctl start antiddos-monitor antiddos-ssh antiddos-xcord 2>/dev/null || true
echo -e "${GREEN}✓ Servicios reiniciados${NC}"

echo
echo -e "${GREEN}✓ Actualización completada a v$(cat VERSION)${NC}"
echo
echo "Ver logs: sudo journalctl -u antiddos-monitor -f"
echo "Verificar: sudo bash scripts/test-protections.sh"
