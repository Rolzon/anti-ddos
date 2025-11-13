#!/bin/bash

# Script de actualización segura a v1.0.1
# Preserva configuración y actualiza código

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     ACTUALIZACIÓN A v1.0.1 - ANTI-DDOS             ║${NC}"
echo -e "${BLUE}║     Protección Docker/Pterodactyl                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
    exit 1
fi

# Verificar que estamos en el directorio correcto
if [ ! -f "VERSION" ]; then
    echo -e "${RED}Error: Ejecuta este script desde el directorio del proyecto${NC}"
    exit 1
fi

CURRENT_VERSION=$(cat VERSION | tr -d '\n\r')
echo -e "${YELLOW}Versión actual: ${CURRENT_VERSION}${NC}"
echo -e "${YELLOW}Versión nueva: 1.0.1${NC}"
echo

if [ "$CURRENT_VERSION" = "1.0.1" ]; then
    echo -e "${GREEN}✓ Ya estás en la versión 1.0.1${NC}"
    echo
    read -p "¿Quieres reinstalar de todas formas? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

echo -e "${YELLOW}Esta actualización incluye:${NC}"
echo "  ✓ Protección de cadenas Docker (DOCKER, DOCKER-ISOLATION-*)"
echo "  ✓ Protección explícita de subnet 172.18.0.0/16"
echo "  ✓ Bloqueo automático de operaciones peligrosas"
echo "  ✓ Limpieza segura que preserva Docker/Pterodactyl"
echo "  ✓ Nueva documentación de seguridad"
echo

read -p "¿Continuar con la actualización? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Actualización cancelada${NC}"
    exit 0
fi

echo
echo -e "${GREEN}Iniciando actualización...${NC}"
echo

# ============================================
# 1. BACKUP DE CONFIGURACIÓN
# ============================================
echo -e "${YELLOW}[1/8] Creando backup de configuración...${NC}"

BACKUP_DIR="/tmp/antiddos-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup de configuración
if [ -f "/etc/antiddos/config.yaml" ]; then
    cp /etc/antiddos/config.yaml "$BACKUP_DIR/"
    echo -e "${GREEN}✓ Backup de config.yaml${NC}"
fi

# Backup de listas
if [ -f "/etc/antiddos/whitelist.txt" ]; then
    cp /etc/antiddos/whitelist.txt "$BACKUP_DIR/"
    echo -e "${GREEN}✓ Backup de whitelist.txt${NC}"
fi

if [ -f "/etc/antiddos/blacklist.txt" ]; then
    cp /etc/antiddos/blacklist.txt "$BACKUP_DIR/"
    echo -e "${GREEN}✓ Backup de blacklist.txt${NC}"
fi

echo -e "${GREEN}✓ Backup guardado en: $BACKUP_DIR${NC}"

# ============================================
# 2. DETENER SERVICIOS
# ============================================
echo
echo -e "${YELLOW}[2/8] Deteniendo servicios...${NC}"

systemctl stop antiddos-monitor 2>/dev/null && echo "  ✓ antiddos-monitor detenido"
systemctl stop antiddos-ssh 2>/dev/null && echo "  ✓ antiddos-ssh detenido"
systemctl stop antiddos-xcord 2>/dev/null && echo "  ✓ antiddos-xcord detenido"

echo -e "${GREEN}✓ Servicios detenidos${NC}"

# ============================================
# 3. ACTUALIZAR CÓDIGO DESDE GITHUB
# ============================================
echo
echo -e "${YELLOW}[3/8] Actualizando código desde GitHub...${NC}"

# Verificar si hay cambios locales
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}! Hay cambios locales no guardados${NC}"
    read -p "¿Descartar cambios locales y actualizar? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git reset --hard HEAD
        echo -e "${GREEN}✓ Cambios locales descartados${NC}"
    else
        echo -e "${RED}Actualización cancelada${NC}"
        exit 1
    fi
fi

# Pull desde GitHub
git fetch origin
git checkout main
git pull origin main

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Código actualizado desde GitHub${NC}"
else
    echo -e "${RED}✗ Error al actualizar desde GitHub${NC}"
    exit 1
fi

# Verificar versión
NEW_VERSION=$(cat VERSION | tr -d '\n\r')
echo -e "${GREEN}✓ Nueva versión: $NEW_VERSION${NC}"

# ============================================
# 4. ACTUALIZAR PAQUETE PYTHON
# ============================================
echo
echo -e "${YELLOW}[4/8] Actualizando paquete Python...${NC}"

pip3 install -e . --upgrade

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Paquete Python actualizado${NC}"
else
    echo -e "${RED}✗ Error al actualizar paquete Python${NC}"
    exit 1
fi

# ============================================
# 5. RESTAURAR CONFIGURACIÓN
# ============================================
echo
echo -e "${YELLOW}[5/8] Restaurando configuración...${NC}"

# Restaurar config.yaml si existe backup
if [ -f "$BACKUP_DIR/config.yaml" ]; then
    cp "$BACKUP_DIR/config.yaml" /etc/antiddos/config.yaml
    echo -e "${GREEN}✓ config.yaml restaurado${NC}"
fi

# Restaurar listas
if [ -f "$BACKUP_DIR/whitelist.txt" ]; then
    cp "$BACKUP_DIR/whitelist.txt" /etc/antiddos/whitelist.txt
    echo -e "${GREEN}✓ whitelist.txt restaurado${NC}"
fi

if [ -f "$BACKUP_DIR/blacklist.txt" ]; then
    cp "$BACKUP_DIR/blacklist.txt" /etc/antiddos/blacklist.txt
    echo -e "${GREEN}✓ blacklist.txt restaurado${NC}"
fi

echo -e "${GREEN}✓ Configuración restaurada${NC}"

# ============================================
# 6. REINICIAR SERVICIOS
# ============================================
echo
echo -e "${YELLOW}[6/8] Reiniciando servicios...${NC}"

systemctl daemon-reload

systemctl start antiddos-monitor 2>/dev/null && echo "  ✓ antiddos-monitor iniciado"
systemctl start antiddos-ssh 2>/dev/null && echo "  ✓ antiddos-ssh iniciado"
systemctl start antiddos-xcord 2>/dev/null && echo "  ✓ antiddos-xcord iniciado"

# Esperar un momento para que los servicios inicien
sleep 2

# Verificar estado
if systemctl is-active --quiet antiddos-monitor; then
    echo -e "${GREEN}✓ antiddos-monitor está activo${NC}"
else
    echo -e "${RED}✗ antiddos-monitor no está activo${NC}"
    echo "  Ver logs: sudo journalctl -u antiddos-monitor -n 50"
fi

# ============================================
# 7. VERIFICAR PROTECCIONES
# ============================================
echo
echo -e "${YELLOW}[7/8] Verificando protecciones Docker/Pterodactyl...${NC}"

# Verificar subnet protegida
if iptables -L INPUT -n | grep -q "172.18.0.0/16"; then
    echo -e "${GREEN}✓ Subnet 172.18.0.0/16 protegida${NC}"
else
    echo -e "${YELLOW}! Subnet 172.18.0.0/16 no encontrada (se agregará al reiniciar)${NC}"
fi

# Verificar cadenas Docker
if iptables -t nat -L DOCKER -n &>/dev/null; then
    echo -e "${GREEN}✓ Cadena DOCKER intacta${NC}"
else
    echo -e "${YELLOW}! Cadena DOCKER no encontrada${NC}"
fi

# Verificar que Docker está corriendo
if systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓ Docker está activo${NC}"
else
    echo -e "${RED}✗ Docker no está activo${NC}"
fi

# Verificar que Wings está corriendo
if systemctl is-active --quiet wings; then
    echo -e "${GREEN}✓ Wings está activo${NC}"
else
    echo -e "${YELLOW}! Wings no está activo${NC}"
fi

# ============================================
# 8. EJECUTAR TEST DE PROTECCIONES
# ============================================
echo
echo -e "${YELLOW}[8/8] Ejecutando test de protecciones...${NC}"

if [ -f "scripts/test-protections.sh" ]; then
    bash scripts/test-protections.sh
else
    echo -e "${YELLOW}! Script de test no encontrado${NC}"
fi

# ============================================
# RESUMEN FINAL
# ============================================
echo
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          ACTUALIZACIÓN COMPLETADA                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo

echo -e "${BLUE}Resumen:${NC}"
echo "  ✓ Versión anterior: $CURRENT_VERSION"
echo "  ✓ Versión nueva: $NEW_VERSION"
echo "  ✓ Backup guardado en: $BACKUP_DIR"
echo "  ✓ Configuración preservada"
echo "  ✓ Servicios reiniciados"
echo

echo -e "${BLUE}Nuevas características v1.0.1:${NC}"
echo "  ✓ Protección de cadenas Docker (DOCKER, DOCKER-ISOLATION-*)"
echo "  ✓ Protección explícita de subnet 172.18.0.0/16"
echo "  ✓ Bloqueo automático de operaciones peligrosas"
echo "  ✓ Limpieza segura que preserva Docker/Pterodactyl"
echo

echo -e "${BLUE}Documentación nueva:${NC}"
echo "  • docs/FIREWALL_SAFETY.md - Guía completa de seguridad"
echo "  • GARANTIAS_DOCKER.md - Garantías técnicas"
echo "  • SECURITY_UPDATE.md - Guía de actualización"
echo

echo -e "${BLUE}Verificación:${NC}"
echo
echo "Ver logs en tiempo real:"
echo "  sudo journalctl -u antiddos-monitor -f"
echo
echo "Ver estado de servicios:"
echo "  sudo systemctl status antiddos-monitor"
echo
echo "Ver reglas de firewall:"
echo "  sudo iptables -L -n -v --line-numbers"
echo
echo "Verificar protecciones:"
echo "  sudo bash scripts/test-protections.sh"
echo
echo "Ver logs de operaciones bloqueadas:"
echo "  sudo tail -f /var/log/antiddos/antiddos.log | grep BLOCKED"
echo

echo -e "${GREEN}✓ Actualización exitosa a v1.0.1${NC}"
echo -e "${GREEN}✓ Docker y Pterodactyl Wings están protegidos${NC}"
echo
