#!/bin/bash
# Script de verificación para configuración gaming-optimizada
# Valida que todos los umbrales y configuraciones sean correctos

set -e

echo "======================================"
echo "Test de Configuración Gaming-Optimizada"
echo "======================================"
echo ""

CONFIG_FILE="/etc/antiddos/config.yaml"
ERRORS=0
WARNINGS=0

# Función para verificar valor en config
check_config_value() {
    local key="$1"
    local expected="$2"
    local operator="${3:-eq}"  # eq, ge, le
    
    # Extraer valor del YAML (simplificado)
    actual=$(grep -A1 "$key:" "$CONFIG_FILE" | tail -1 | awk '{print $NF}' | tr -d '"')
    
    if [ -z "$actual" ]; then
        echo "⚠️  ADVERTENCIA: No se encontró '$key' en config"
        ((WARNINGS++))
        return
    fi
    
    case $operator in
        eq)
            if [ "$actual" = "$expected" ]; then
                echo "✅ $key: $actual (correcto)"
            else
                echo "❌ ERROR: $key debe ser $expected, actual: $actual"
                ((ERRORS++))
            fi
            ;;
        ge)
            if [ "$actual" -ge "$expected" ]; then
                echo "✅ $key: $actual (>= $expected, correcto)"
            else
                echo "❌ ERROR: $key debe ser >= $expected, actual: $actual"
                ((ERRORS++))
            fi
            ;;
        le)
            if [ "$actual" -le "$expected" ]; then
                echo "✅ $key: $actual (<= $expected, correcto)"
            else
                echo "❌ ERROR: $key debe ser <= $expected, actual: $actual"
                ((ERRORS++))
            fi
            ;;
    esac
}

echo "=== 1. Verificando Umbrales de Servicio ==="
check_config_value "default_threshold_mbps" "30" "ge"
check_config_value "default_threshold_pps" "3500" "ge"
check_config_value "window_seconds" "10" "ge"
check_config_value "recovery_cycles" "5" "ge"
echo ""

echo "=== 2. Verificando Rate Limiting ==="
# Extraer valores para comparación
threshold_pps=$(grep "default_threshold_pps:" "$CONFIG_FILE" | awk '{print $2}')
limit_pps=$(grep -A2 "auto_rate_limit:" "$CONFIG_FILE" | grep "limit_pps:" | awk '{print $2}')

echo "Threshold PPS: $threshold_pps"
echo "Limit PPS: $limit_pps"

if [ "$limit_pps" -ge 3000 ]; then
    echo "✅ limit_pps: $limit_pps (>= 3000, correcto)"
else
    echo "❌ ERROR: limit_pps debe ser >= 3000, actual: $limit_pps"
    ((ERRORS++))
fi

# Verificar consistencia: limit_pps no debe ser mucho menor que threshold_pps
if [ "$limit_pps" -ge $((threshold_pps - 500)) ]; then
    echo "✅ Consistencia threshold/limit OK (diferencia < 500)"
else
    echo "⚠️  ADVERTENCIA: limit_pps muy bajo comparado con threshold_pps"
    ((WARNINGS++))
fi
echo ""

echo "=== 3. Verificando UDP Blocking ==="
check_config_value "min_pps" "8000" "ge"
check_config_value "ban_connection_threshold" "50" "ge"
echo ""

echo "=== 4. Verificando Blacklist Automático ==="
min_conn=$(grep -A3 "auto_blacklist:" "$CONFIG_FILE" | grep "min_connections:" | awk '{print $2}')
if [ "$min_conn" -ge 60 ]; then
    echo "✅ min_connections: $min_conn (>= 60, correcto)"
else
    echo "⚠️  ADVERTENCIA: min_connections=$min_conn es bajo, recomendado >= 60"
    ((WARNINGS++))
fi
echo ""

echo "=== 5. Verificando DoS Filters ==="
syn_threshold=$(grep -A2 "syn_flood:" "$CONFIG_FILE" | grep "threshold:" | awk '{print $2}')
if [ "$syn_threshold" -ge 100 ]; then
    echo "✅ SYN threshold: $syn_threshold (>= 100, gaming-friendly)"
else
    echo "⚠️  ADVERTENCIA: SYN threshold bajo, puede causar false positives"
    ((WARNINGS++))
fi

udp_threshold=$(grep -A2 "udp_flood:" "$CONFIG_FILE" | grep "threshold:" | head -1 | awk '{print $2}')
if [ "$udp_threshold" -ge 100 ]; then
    echo "✅ UDP threshold: $udp_threshold (>= 100, gaming-friendly)"
else
    echo "⚠️  ADVERTENCIA: UDP threshold bajo, puede causar false positives"
    ((WARNINGS++))
fi

conn_limit=$(grep -A2 "connection_limit:" "$CONFIG_FILE" | grep "max_connections:" | awk '{print $2}')
if [ "$conn_limit" -ge 100 ]; then
    echo "✅ Connection limit: $conn_limit (>= 100, gaming-friendly)"
else
    echo "⚠️  ADVERTENCIA: Connection limit bajo, puede causar false positives"
    ((WARNINGS++))
fi
echo ""

echo "=== 6. Verificando Sistema ==="

# Verificar que el código tiene las mejoras
CODE_FILE="/opt/anti-ddos/src/antiddos/monitor.py"
if [ -f "$CODE_FILE" ]; then
    if grep -q "is_gaming_port" "$CODE_FILE"; then
        echo "✅ Código con detección gaming instalado"
    else
        echo "❌ ERROR: Código NO tiene detección gaming"
        echo "   Ejecutar: cd /opt/anti-ddos && sudo pip3 install -e ."
        ((ERRORS++))
    fi
    
    if grep -q "std_dev" "$CODE_FILE"; then
        echo "✅ Código con análisis estadístico instalado"
    else
        echo "⚠️  ADVERTENCIA: Código sin análisis estadístico avanzado"
        ((WARNINGS++))
    fi
else
    echo "⚠️  ADVERTENCIA: Código no encontrado en /opt/anti-ddos"
    ((WARNINGS++))
fi

# Verificar servicio
if systemctl is-active --quiet antiddos-monitor; then
    echo "✅ Servicio antiddos-monitor activo"
    
    # Verificar logs recientes
    if journalctl -u antiddos-monitor --since "5 minutes ago" | grep -q "Patrón legítimo"; then
        echo "✅ Sistema detectando tráfico legítimo correctamente"
    elif journalctl -u antiddos-monitor --since "5 minutes ago" | grep -q "Initializing"; then
        echo "ℹ️  Sistema iniciado recientemente, esperando tráfico"
    else
        echo "⚠️  No hay logs de detección recientes"
    fi
else
    echo "⚠️  Servicio antiddos-monitor NO está activo"
    echo "   Para iniciar: sudo systemctl start antiddos-monitor"
    ((WARNINGS++))
fi
echo ""

echo "=== 7. Verificando Firewall ==="

# Verificar que NO hay reglas ANTIDDOS conflictivas
if command -v nft &> /dev/null; then
    if nft list table ip filter 2>/dev/null | grep -q "ANTIDDOS"; then
        antiddos_rules=$(nft list table ip filter 2>/dev/null | grep -c "ANTIDDOS" || echo "0")
        echo "ℹ️  Hay $antiddos_rules referencias a ANTIDDOS en nftables"
        echo "   Esto es normal si el servicio está activo"
    else
        echo "✅ No hay reglas ANTIDDOS residuales"
    fi
fi

# Verificar reglas Docker
if nft list table ip filter 2>/dev/null | grep -q "DOCKER"; then
    echo "✅ Reglas Docker presentes (normal)"
else
    echo "⚠️  ADVERTENCIA: No se detectaron reglas Docker"
    ((WARNINGS++))
fi
echo ""

echo "======================================"
echo "RESUMEN"
echo "======================================"
echo "Errores críticos: $ERRORS"
echo "Advertencias: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ ¡Configuración PERFECTA para gaming servers!"
    echo ""
    echo "Próximos pasos:"
    echo "1. Iniciar servicio: sudo systemctl start antiddos-monitor"
    echo "2. Monitorear logs: sudo journalctl -u antiddos-monitor -f"
    echo "3. Probar con jugadores reales durante 1-2 horas"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  Configuración FUNCIONAL con advertencias menores"
    echo ""
    echo "Puedes usar el sistema, pero considera revisar las advertencias."
    exit 0
else
    echo "❌ HAY ERRORES CRÍTICOS que deben corregirse"
    echo ""
    echo "Acciones requeridas:"
    echo "1. Corregir los valores en $CONFIG_FILE"
    echo "2. Reinstalar código: cd /opt/anti-ddos && sudo pip3 install -e ."
    echo "3. Ejecutar este test nuevamente"
    exit 1
fi
