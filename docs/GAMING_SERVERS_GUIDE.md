# Guía de Configuración para Servidores Gaming (Minecraft/Pterodactyl)

## 📋 Índice

1. [Introducción](#introducción)
2. [Configuración Recomendada](#configuración-recomendada)
3. [Detección Inteligente de Gaming](#detección-inteligente-de-gaming)
4. [Umbrales Optimizados](#umbrales-optimizados)
5. [Troubleshooting](#troubleshooting)
6. [Monitoreo](#monitoreo)

---

## Introducción

Este proyecto Anti-DDoS ha sido **completamente optimizado** para servidores gaming, especialmente Minecraft con Pterodactyl/Wings. Las mejoras incluyen:

✅ **Detección automática de puertos gaming** (19000-30000, 25565-25575)
✅ **Análisis estadístico avanzado** para distinguir jugadores legítimos de bots
✅ **Thresholds dinámicos** según tipo de servicio
✅ **Protección sin false positives** - jugadores nunca son bloqueados incorrectamente

---

## Configuración Recomendada

### 1. Umbrales por Servicio

El archivo `config.yaml` ya tiene valores optimizados para gaming:

```yaml
services:
  enabled: true
  default_threshold_mbps: 30      # 30-50 jugadores simultáneos
  default_threshold_pps: 3500     # Threshold alto para evitar false positives
  window_seconds: 10              # Confirmación de 10s antes de actuar
  recovery_cycles: 5              # 5 ciclos para confirmar recuperación
```

**Explicación:**
- `30 Mbps`: Permite 40-50 jugadores activos sin activar mitigación
- `3500 PPS`: Threshold muy alto - solo ataques reales lo superan
- `10s window`: Evita reaccionar a picos momentáneos (chunk loading)
- `5 recovery cycles`: Espera 50s antes de quitar mitigación (estabilidad)

### 2. Rate Limiting Inteligente

```yaml
services:
  auto_rate_limit:
    enabled: true
    limit_pps: 3000  # CONSISTENTE con threshold_pps
```

**Importante:** `limit_pps >= threshold_pps` para evitar conflictos.

### 3. Blacklist Automático - MUY SELECTIVO

```yaml
services:
  auto_blacklist:
    enabled: true
    min_connections: 60           # 60+ conexiones simultáneas = ataque claro
    duration_seconds: 3600        # 1 hora de ban
```

**Por qué 60 conexiones:**
- Jugador legítimo: 1-5 conexiones (reconexiones incluidas)
- Bot simple: 10-20 conexiones
- Ataque DDoS: 50+ conexiones por IP

### 4. UDP Blocking - SOLO ATAQUES EXTREMOS

```yaml
services:
  auto_udp_block:
    enabled: true
    min_pps: 8000                 # 8000 PPS = ataque masivo
    ban_connection_threshold: 50  # 50+ conexiones por IP
    ban_duration_seconds: 1800    # 30 minutos
```

**Por qué 8000 PPS:**
- 20 jugadores activos: ~1500 PPS
- 50 jugadores activos: ~3500 PPS
- Ataque DDoS real: >8000 PPS sostenido

---

## Detección Inteligente de Gaming

El sistema ahora detecta automáticamente puertos gaming y aplica lógica especial:

### Rangos de Puertos Gaming Detectados

```python
# Detección automática en el código
is_gaming_port = (
    (19000 <= port <= 30000) or  # Rango Pterodactyl/Minecraft
    (27000 <= port <= 27050) or  # Source Engine games
    (25565 <= port <= 25575)     # Minecraft default range
)
```

### Criterios de Detección de Ataques

#### 1. **Distribución de IPs**

```
Gaming Legítimo:  5-20 IPs únicas
Ataque DDoS:      25+ IPs únicas (gaming) / 15+ (no-gaming)
```

#### 2. **Análisis Estadístico (Desviación Estándar)**

```
Gaming:   Distribución normal con outliers ocasionales (<30%)
Ataque:   Muchos outliers extremos (>30% de IPs sospechosas)
```

Ejemplo:
```
Gaming: [5, 6, 4, 5, 12, 5, 6]  → σ=2.5, outliers=1 (14%) ✓ Legítimo
Ataque: [45, 50, 48, 52, 47, 49] → σ=2.2, avg=48.5, todos altos ✗ Ataque
```

#### 3. **PPS por IP**

```
Gaming UDP:      20-300 PPS por jugador
Bot/Ataque:      >800 PPS por IP (gaming) / >500 PPS (no-gaming)
```

#### 4. **Ratio PPS/Conexión**

```
Gaming:          5-30 PPS por conexión
Flood Attack:    >150 PPS por conexión (paquetes pequeños masivos)
```

---

## Umbrales Optimizados

### Tabla de Referencias

| Escenario | Jugadores | PPS Esperado | Mbps Esperado | Threshold Config |
|-----------|-----------|--------------|---------------|------------------|
| Servidor pequeño | 5-10 | 300-800 | 2-5 | threshold_pps: 2000 |
| Servidor mediano | 20-30 | 1500-2500 | 10-20 | threshold_pps: 3500 |
| Servidor grande | 40-60 | 3000-4500 | 25-40 | threshold_pps: 5000 |
| Red multi-servidor | 100+ | 8000+ | 60+ | threshold_pps: 10000 |

### Ajustes Personalizados

Si tienes un servidor **MUY grande** (80+ jugadores simultáneos):

```yaml
services:
  default_threshold_mbps: 50
  default_threshold_pps: 6000
  
  auto_rate_limit:
    limit_pps: 5000
  
  auto_udp_block:
    min_pps: 12000
    ban_connection_threshold: 80
```

---

## Troubleshooting

### ❌ Problema: Jugadores aún desconectados

**Diagnóstico:**

1. **Verificar que NO hay reglas Anti-DDoS activas:**
```bash
sudo nft list table ip filter | grep ANTIDDOS
# No debe mostrar nada
```

2. **Ver logs en tiempo real:**
```bash
sudo journalctl -u antiddos-monitor -f
```

Buscar:
- ✅ `Patrón legítimo: solo X IPs únicas` → Sistema funcionando correctamente
- ⚠️ `Patrón de ataque detectado` → Ajustar thresholds (ver abajo)
- ⚠️ `IP X bloqueada` → Verificar si es jugador legítimo (agregar a whitelist)

3. **Verificar Wings daemon:**
```bash
sudo journalctl -u wings -n 50
```

Si ves errores SQL o "SFTP cron failed", el problema es Wings, NO el firewall.

### ⚙️ Ajustar Thresholds si hay False Positives

Si el sistema marca jugadores legítimos como atacantes:

1. **Aumentar threshold global:**
```yaml
services:
  default_threshold_pps: 5000  # Aumentar de 3500 a 5000
```

2. **Hacer blacklist más selectivo:**
```yaml
services:
  auto_blacklist:
    min_connections: 80  # Aumentar de 60 a 80
```

3. **Deshabilitar UDP blocking temporal:**
```yaml
services:
  auto_udp_block:
    enabled: false  # Deshabilitar temporalmente
```

### 📊 Monitoreo en Tiempo Real

```bash
# Ver estadísticas de servicios
cat /var/run/antiddos/service_stats.json | jq '.'

# Ver IPs bloqueadas
cat /etc/antiddos/blacklist.txt

# Ver tráfico de un servicio específico
sudo tcpdump -i dr0 'udp port 19671' -c 100
```

---

## Monitoreo

### Métricas Clave

```bash
# Ver PPS actual de un contenedor
sudo docker stats --no-stream <container_name>

# Ver conexiones activas a un puerto gaming
sudo ss -ntu | grep ':19671' | wc -l

# Top IPs conectadas
sudo ss -ntu | grep ':19671' | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -10
```

### Notificaciones Discord

El sistema envía alertas automáticas a Discord cuando:
- ✅ Se detecta un ataque real (con análisis estadístico)
- ✅ Se bloquean IPs (solo atacantes confirmados)
- ✅ Se activa rate limiting
- ⚠️ Se bloquea un puerto (último recurso)

**Formato de alerta:**
```
🚨 Ataque detectado en MC Survival
📊 3500 PPS | 25 Mbps | 35 conexiones
🔍 Patrón de ataque confirmado: 28 IPs sospechosas (65%)
🛡️ Mitigación aplicada: Rate limit 3000 PPS
🚫 15 IPs bloqueadas (top atacantes)
```

---

## Resumen de Mejoras Aplicadas

### ✅ Código (`monitor.py`)

1. **Detección automática de puertos gaming** (líneas 326-337)
2. **Análisis estadístico con desviación estándar** (líneas 355-382)
3. **Thresholds dinámicos por tipo de servicio** (líneas 345, 373, 390)
4. **Ratio PPS/Conexión para detectar floods** (líneas 398-407)
5. **Criterio adicional: promedio 1.5x** para banear IPs (líneas 445-450)
6. **Seguridad: no banear si <8 IPs atacan** (líneas 476-485)
7. **Rate limiting gradual** según severidad (líneas 510-518)

### ✅ Configuración (`config.yaml`)

1. **Umbrales consistentes** (3500 PPS threshold, 3000 PPS limit)
2. **Blacklist más selectivo** (60 conexiones mínimo)
3. **UDP blocking solo ataques extremos** (8000 PPS, 50 conexiones)
4. **DoS filters más permisivos** (150 threshold SYN/UDP/connections)

---

## Siguientes Pasos

1. **Instalar con los nuevos cambios:**
```bash
cd /opt/anti-ddos
sudo pip3 install -e .
```

2. **Reiniciar servicio:**
```bash
sudo systemctl restart antiddos-monitor
```

3. **Monitorear durante 1 hora:**
```bash
sudo journalctl -u antiddos-monitor -f
```

4. **Verificar que jugadores NO se desconecten**

5. **Si todo funciona bien, monitorear por 24-48 horas**

---

## Soporte

Si aún tienes problemas:

1. Exportar logs:
```bash
sudo journalctl -u antiddos-monitor --since "1 hour ago" > antiddos-debug.log
sudo journalctl -u wings --since "1 hour ago" > wings-debug.log
```

2. Verificar configuración:
```bash
cat /etc/antiddos/config.yaml | grep -A5 "services:"
```

3. Ver estadísticas actuales:
```bash
cat /var/run/antiddos/service_stats.json | jq '.services[] | {name, pps_in, pps_out, connections, mitigation}'
```

---

**Última actualización:** 2024-11-21
**Versión:** 2.0 - Gaming Optimized
