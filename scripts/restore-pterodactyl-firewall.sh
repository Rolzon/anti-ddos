#!/bin/bash
# Restaurar firewall a configuración predeterminada de Pterodactyl/Wings
# Elimina todas las reglas agregadas por Anti-DDoS

set -e

echo "======================================"
echo "Restaurando firewall de Pterodactyl/Wings"
echo "======================================"

# 1. Detener servicios Anti-DDoS
echo ""
echo "[1/6] Deteniendo servicios Anti-DDoS..."
systemctl stop antiddos-monitor antiddos-ssh antiddos-xcord 2>/dev/null || true
systemctl disable antiddos-monitor antiddos-ssh antiddos-xcord 2>/dev/null || true
echo "✓ Servicios Anti-DDoS detenidos"

# 2. Respaldar configuración actual
echo ""
echo "[2/6] Respaldando configuración actual..."
BACKUP_FILE="/tmp/nftables-backup-$(date +%Y%m%d-%H%M%S).txt"
nft list ruleset > "$BACKUP_FILE" 2>/dev/null || true
echo "✓ Respaldo guardado en: $BACKUP_FILE"

# 3. Eliminar cadenas ANTIDDOS si existen
echo ""
echo "[3/6] Eliminando cadenas ANTIDDOS..."
for chain in ANTIDDOS ANTIDDOS_WINGS_8080 ANTIDDOS_MYSQL_3306 ANTIDDOS_SSH_22 ANTIDDOS_XCORD_6000; do
    # Eliminar saltos desde INPUT
    iptables-nft -D INPUT -j $chain 2>/dev/null || true
    # Eliminar saltos desde FORWARD
    iptables-nft -D FORWARD -j $chain 2>/dev/null || true
    # Eliminar saltos desde OUTPUT
    iptables-nft -D OUTPUT -j $chain 2>/dev/null || true
    
    # Flush y eliminar cadena
    iptables-nft -F $chain 2>/dev/null || true
    iptables-nft -X $chain 2>/dev/null || true
done
echo "✓ Cadenas ANTIDDOS eliminadas"

# 4. Limpiar TODAS las reglas DROP individuales de FORWARD
echo ""
echo "[4/6] Limpiando reglas DROP de la cadena FORWARD..."
echo "Esto puede tardar 1-2 minutos..."

# Obtener número de reglas DROP en FORWARD
DROP_COUNT=$(nft list chain ip filter FORWARD | grep -c "drop" || echo "0")
echo "Encontradas $DROP_COUNT reglas DROP para eliminar"

if [ "$DROP_COUNT" -gt 0 ]; then
    # Método 1: Intentar eliminar por posición (más rápido pero puede fallar)
    echo "Eliminando reglas DROP..."
    
    # Usar nft para eliminar las reglas directamente
    # Primero, obtener los handles de todas las reglas DROP
    nft -a list chain ip filter FORWARD | grep "drop" | awk '{print $NF}' | while read handle; do
        nft delete rule ip filter FORWARD handle $handle 2>/dev/null || true
    done
    
    echo "✓ Reglas DROP eliminadas"
else
    echo "✓ No hay reglas DROP para eliminar"
fi

# 5. Reiniciar Docker para regenerar reglas nativas
echo ""
echo "[5/6] Reiniciando Docker para regenerar reglas nativas..."
systemctl restart docker
echo "Esperando 10 segundos para que Docker se estabilice..."
sleep 10
echo "✓ Docker reiniciado"

# 6. Reiniciar Wings para regenerar reglas de Pterodactyl
echo ""
echo "[6/6] Reiniciando Wings para regenerar reglas de Pterodactyl..."
systemctl restart wings
echo "Esperando 15 segundos para que Wings sincronice..."
sleep 15
echo "✓ Wings reiniciado"

# Verificación final
echo ""
echo "======================================"
echo "Verificando configuración final..."
echo "======================================"

# Verificar que no existan cadenas ANTIDDOS
echo ""
echo "1. Verificando que no existan cadenas ANTIDDOS:"
if nft list table ip filter | grep -q "ANTIDDOS"; then
    echo "⚠ ADVERTENCIA: Aún existen cadenas ANTIDDOS"
    nft list table ip filter | grep "ANTIDDOS"
else
    echo "✓ No hay cadenas ANTIDDOS"
fi

# Verificar reglas DROP en FORWARD
echo ""
echo "2. Verificando reglas DROP en FORWARD:"
DROP_COUNT=$(nft list chain ip filter FORWARD | grep -c "drop" || echo "0")
if [ "$DROP_COUNT" -gt 0 ]; then
    echo "⚠ ADVERTENCIA: Aún hay $DROP_COUNT reglas DROP en FORWARD"
    echo "Ejecutar manualmente: nft flush chain ip filter FORWARD"
else
    echo "✓ No hay reglas DROP en FORWARD"
fi

# Verificar cadenas Docker
echo ""
echo "3. Verificando cadenas Docker existentes:"
nft list table ip filter | grep "chain DOCKER" | head -n 5
echo "✓ Cadenas Docker presentes"

# Verificar servicios
echo ""
echo "4. Verificando servicios:"
echo -n "Docker: "
systemctl is-active docker
echo -n "Wings: "
systemctl is-active wings
echo -n "Anti-DDoS Monitor: "
systemctl is-active antiddos-monitor || echo "inactive (correcto)"

echo ""
echo "======================================"
echo "RESTAURACIÓN COMPLETADA"
echo "======================================"
echo ""
echo "El firewall ahora tiene solo reglas de Docker y Pterodactyl/Wings."
echo ""
echo "PRÓXIMOS PASOS:"
echo "1. Probar conectividad de jugadores por 10-15 minutos"
echo "2. Si aún hay desconexiones, el problema NO es el firewall"
echo "3. Revisar logs de Wings: journalctl -u wings -f"
echo "4. Revisar logs de contenedores: docker logs <container_name>"
echo ""
echo "Backup guardado en: $BACKUP_FILE"
echo ""
