#!/bin/bash

# Script para simular un ataque DDoS y probar notificaciones de Discord
# SOLO PARA PRUEBAS - No usar en producción

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Simulador de Ataque DDoS para Pruebas ===${NC}"
echo -e "${YELLOW}Este script simulará un ataque para probar las notificaciones de Discord${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
    exit 1
fi

# Verificar que el servicio está corriendo
if ! systemctl is-active --quiet antiddos-monitor; then
    echo -e "${RED}Error: El servicio antiddos-monitor no está corriendo${NC}"
    echo "Iniciar con: sudo systemctl start antiddos-monitor"
    exit 1
fi

echo -e "${BLUE}Opciones de prueba:${NC}"
echo "1. Probar notificación de Discord (sin ataque real)"
echo "2. Simular ataque de tráfico (genera tráfico real)"
echo "3. Simular bloqueo de IP (agrega IP a blacklist)"
echo "4. Simular ataque SSH (intentos fallidos)"
echo "5. Ver configuración de Discord"
echo
read -p "Selecciona una opción (1-5): " option

case $option in
    1)
        echo
        echo -e "${YELLOW}[Opción 1] Probando notificación de Discord...${NC}"
        echo
        echo "Ejecutando comando de prueba:"
        antiddos-cli discord test
        ;;
    
    2)
        echo
        echo -e "${YELLOW}[Opción 2] Simulando ataque de tráfico...${NC}"
        echo -e "${RED}⚠ ADVERTENCIA: Esto generará tráfico real en tu red${NC}"
        echo
        read -p "¿Continuar? (s/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
            echo "Cancelado"
            exit 0
        fi
        
        echo
        echo "Instalando herramientas necesarias..."
        apt-get install -y hping3 >/dev/null 2>&1
        
        echo
        echo -e "${BLUE}Generando tráfico de prueba durante 30 segundos...${NC}"
        echo "Esto debería activar la detección de ataque"
        echo
        
        # Obtener interfaz de red
        INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
        
        # Generar tráfico SYN flood hacia localhost (no afecta a otros)
        timeout 30 hping3 -S -p 80 --flood 127.0.0.1 >/dev/null 2>&1 &
        
        echo "Tráfico generado. Monitoreando logs..."
        echo
        echo "Ver logs en tiempo real:"
        echo "  sudo journalctl -u antiddos-monitor -f"
        echo
        echo "Espera 30-60 segundos y revisa Discord para la notificación"
        ;;
    
    3)
        echo
        echo -e "${YELLOW}[Opción 3] Simulando bloqueo de IP...${NC}"
        echo
        
        # IP de prueba (no bloquear IPs reales)
        TEST_IP="1.2.3.4"
        
        echo "Bloqueando IP de prueba: $TEST_IP"
        echo "Esto debería enviar notificación de Discord"
        echo
        
        antiddos-cli blacklist add "$TEST_IP" "Prueba de notificación Discord"
        
        echo
        echo -e "${GREEN}✓ IP bloqueada${NC}"
        echo "Revisa Discord para la notificación de bloqueo"
        echo
        echo "Para desbloquear después:"
        echo "  sudo antiddos-cli blacklist remove $TEST_IP"
        ;;
    
    4)
        echo
        echo -e "${YELLOW}[Opción 4] Simulando ataque SSH...${NC}"
        echo
        
        # Verificar que SSH protection está activo
        if ! systemctl is-active --quiet antiddos-ssh; then
            echo -e "${RED}Error: antiddos-ssh no está corriendo${NC}"
            echo "Iniciar con: sudo systemctl start antiddos-ssh"
            exit 1
        fi
        
        echo "Generando intentos fallidos de SSH..."
        echo "Esto debería activar el ban automático y notificación"
        echo
        
        # Simular intentos fallidos (escribir en el log que monitorea el sistema)
        for i in {1..6}; do
            logger -t sshd "Failed password for testuser from 5.6.7.8 port 12345 ssh2"
            echo "  Intento fallido $i/6"
            sleep 1
        done
        
        echo
        echo -e "${GREEN}✓ Intentos fallidos simulados${NC}"
        echo "Revisa Discord para la notificación de ataque SSH"
        echo
        echo "Ver logs:"
        echo "  sudo journalctl -u antiddos-ssh -f"
        ;;
    
    5)
        echo
        echo -e "${YELLOW}[Opción 5] Configuración de Discord${NC}"
        echo
        
        CONFIG_FILE="/etc/antiddos/config.yaml"
        
        if [ ! -f "$CONFIG_FILE" ]; then
            echo -e "${RED}Error: Archivo de configuración no encontrado${NC}"
            exit 1
        fi
        
        echo "Configuración actual de Discord:"
        echo
        grep -A 20 "discord:" "$CONFIG_FILE" | grep -v "^#"
        echo
        
        echo -e "${BLUE}Para configurar Discord:${NC}"
        echo "1. Editar: sudo nano /etc/antiddos/config.yaml"
        echo "2. Buscar sección 'discord:'"
        echo "3. Configurar:"
        echo "   - enabled: true"
        echo "   - webhook_url: 'TU_WEBHOOK_URL'"
        echo "   - notify_attacks: true"
        echo "   - notify_blocks: true"
        echo "4. Reiniciar: sudo systemctl restart antiddos-monitor"
        ;;
    
    *)
        echo -e "${RED}Opción inválida${NC}"
        exit 1
        ;;
esac

echo
echo -e "${GREEN}=== Prueba Completada ===${NC}"
echo
echo -e "${BLUE}Verificar notificaciones:${NC}"
echo "1. Revisa tu canal de Discord"
echo "2. Ver logs del sistema:"
echo "   sudo journalctl -u antiddos-monitor -n 50"
echo
echo "3. Ver estadísticas:"
echo "   sudo antiddos-cli stats"
