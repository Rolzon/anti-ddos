# 🛡️ Protección Balanceada: Gaming + Anti-DDoS

## 🎯 Objetivo

Crear un sistema que:
- ✅ **NO bloquea jugadores legítimos** (incluso con 50+ jugadores simultáneos)
- ✅ **SÍ mitiga ataques DDoS reales** (detecta y bloquea ataques de verdad)
- ✅ **Distingue inteligentemente** entre tráfico gaming y ataque

## 📊 Escenarios y Respuestas

### Escenario 1: Gaming Normal (10-30 jugadores)

```
Tráfico: 500-1500 PPS, 10-20 Mbps
IPs únicas: 10-30
Conexiones por IP: 1-5
```

**Respuesta del sistema:**
- ✅ Permitir TODO el tráfico
- ✅ NO aplicar rate limiting
- ✅ NO banear ninguna IP
- ℹ️ Monitorear pero no intervenir

**Filtros activos:**
- Filtros DoS globales (>1000 PPS UDP)
- Límites por IP (100 SYN, 100 connections TCP)

### Escenario 2: Gaming Intenso (50-100 jugadores)

```
Tráfico: 2000-4000 PPS, 20-50 Mbps
IPs únicas: 50-100
Conexiones por IP: 1-3
```

**Respuesta del sistema:**
- ✅ Permitir TODO el tráfico
- ℹ️ Threshold de servicio excedido PERO:
  - Análisis de patrón: ❌ NO es ataque (pocas IPs, distribución normal)
  - NO aplicar mitigación
  - Solo logging para monitoreo

**Log esperado:**
```
[INFO] Tráfico alto en Minecraft Server: 3500 PPS, 100 IPs
[DEBUG] Patrón legítimo: solo 100 IPs únicas
[DEBUG] Tráfico alto pero patrón legítimo: 100 IPs, avg 2.0 conn/IP, 3500 PPS total
```

### Escenario 3: Ataque DDoS Pequeño (botnet)

```
Tráfico: 3000-5000 PPS, 30-60 Mbps
IPs únicas: 200-500 (muchas IPs)
Conexiones por IP: 5-20 (muchas conexiones por bot)
```

**Respuesta del sistema:**
- ⚠️ Análisis de patrón: ✅ ES ATAQUE
  - Muchas IPs únicas (>200)
  - 20%+ de IPs con conexiones 3x sobre el promedio
  - PPS por IP alto (>500)

**Acciones:**
1. 🎯 **Banear top 20% de IPs atacantes** (40-100 IPs bloqueadas)
   - Solo IPs con >30 conexiones simultáneas
   - Duración: 1 hora
   - Respeta whitelist

2. ⚡ **Rate limiting al puerto** (1500 PPS)
   - Permite gaming legítimo continuar
   - Limita capacidad de ataque

3. 📊 **Notificación Discord** con detalles del ataque

**Jugadores legítimos:**
- ✅ Siguen jugando sin problemas
- ✅ No son baneados (conexiones normales)
- ✅ Pueden experimentar lag leve por rate limiting

### Escenario 4: Ataque DDoS Masivo UDP

```
Tráfico: 8000-15000 PPS, 80-150 Mbps
IPs únicas: 500+
Conexiones por IP: 10-50
Protocolo: UDP flood
```

**Respuesta del sistema:**
- 🚨 **ATAQUE MASIVO CONFIRMADO**
  - PPS >5000 en servicio UDP
  - Patrón de ataque confirmado

**Acciones escalonadas:**
1. 🎯 Banear top 20% IPs atacantes (>30 conexiones)
2. 🔥 **Banear IPs con >20 conexiones UDP** (específico para UDP)
3. ⚡ **Rate limiting restrictivo** (750 PPS - mitad del normal)
4. 📱 Notificación crítica

**Jugadores legítimos:**
- ⚠️ Pueden experimentar lag moderado
- ✅ Whitelist protege IPs conocidas
- ✅ IPs con tráfico normal (<20 conn) siguen activas

### Escenario 5: Ataque DDoS EXTREMO

```
Tráfico: >20000 PPS, >200 Mbps
IPs únicas: 1000+
Conexiones: Flood masivo
```

**Respuesta del sistema:**
- 🔴 **ATAQUE EXTREMO**
  - PPS >10000 en servicio UDP
  - Saturación de red

**Acciones drásticas:**
1. 🎯 Banear masivo de IPs atacantes
2. ⚡ Rate limiting muy restrictivo (750 PPS)
3. 🚫 **BLOQUEO TOTAL DEL PUERTO** (último recurso)
   - Solo si PPS >10000
   - Protege infraestructura
4. 🌍 **Mitigación global activada**
   - Strict limits aplicados
   - Filtrado por país (si configurado)
5. 📱 Alerta crítica múltiple

**Estado del servicio:**
- 🔴 Servicio temporalmente inaccesible
- ✅ Infraestructura protegida
- ⏱️ Auto-recuperación cuando PPS baje

### Escenario 6: Ataque Global a Múltiples Servicios

```
Tráfico total: >200 Mbps o >50000 PPS
Servicios afectados: 3+
```

**Respuesta del sistema:**
- 🌍 **MITIGACIÓN GLOBAL ACTIVADA**

**Acciones globales:**
1. 🛡️ **Strict limits**
   - SYN global: 3000/s
   - UDP global: 10000/s
   - ICMP: 500/s

2. 🌍 **Filtrado por país** (si configurado)
   - Bloquear países de blacklist (CN, RU, KP)
   - Solo durante el ataque

3. 🎯 **Blacklist masivo**
   - IPs con >80 conexiones/segundo
   - Ban global de 1 hora

4. 📊 **Reporte de ataque**
   - Duración
   - IPs bloqueadas
   - Tráfico mitigado

**Servicios gaming:**
- ⚠️ Pueden experimentar lag
- ✅ Siguen funcionando
- ✅ Whitelist protege jugadores conocidos

## 🧠 Análisis Inteligente de Patrones

### Algoritmo de Detección

```python
def _analyze_attack_pattern(stats):
    # Criterio 1: Número de IPs
    if unique_ips < 10:
        return False  # Gaming legítimo
    
    # Criterio 2: Distribución de conexiones
    suspicious_ips = count(ips with >3x average connections)
    if suspicious_ips > 20% of total:
        return True  # Ataque: distribución anormal
    
    # Criterio 3: PPS por IP
    pps_per_ip = total_pps / unique_ips
    if pps_per_ip > 500:
        return True  # Ataque: tráfico por IP muy alto
    
    return False  # Gaming legítimo con tráfico alto
```

### Ejemplos de Clasificación

| IPs | PPS Total | PPS/IP | Conn/IP | Clasificación |
|-----|-----------|--------|---------|---------------|
| 20 | 1500 | 75 | 2 | ✅ Gaming legítimo |
| 100 | 4000 | 40 | 2 | ✅ Gaming intenso |
| 200 | 5000 | 25 | 15 | ⚠️ ATAQUE (muchas IPs con muchas conn) |
| 50 | 30000 | 600 | 5 | ⚠️ ATAQUE (PPS/IP muy alto) |
| 500 | 8000 | 16 | 8 | ⚠️ ATAQUE (muchas IPs, patrón de botnet) |

## 🎚️ Configuración de Thresholds

### Por Servicio (Individual)

```yaml
services:
  default_threshold_mbps: 20    # Permite 20-30 jugadores
  default_threshold_pps: 2000   # Alto para evitar false positives
  
  auto_rate_limit:
    enabled: true
    limit_pps: 1500             # Rate limit permisivo
  
  auto_udp_block:
    enabled: true
    min_pps: 5000               # SOLO ataques masivos
    ban_connection_threshold: 20 # 20+ conexiones = sospechoso
  
  auto_blacklist:
    enabled: true
    min_connections: 30         # Balance: 30+ = muy sospechoso
```

### Global (Todo el Servidor)

```yaml
bandwidth:
  threshold_mbps: 200           # Ataque DDoS típico
  threshold_pps: 50000          # 50k+ PPS = ataque claro

blacklist:
  auto_blacklist:
    connections_per_second: 80  # 80 conn/s por IP = bot

dos_filter:
  syn_flood:
    threshold: 100              # 100 SYN simultáneos por IP
  udp_flood:
    threshold: 100              # Base: límite global 1000/s
  connection_limit:
    max_connections: 100        # 100 conexiones TCP por IP
```

## 📈 Mitigación Escalonada

### Nivel 1: Monitoreo (No intervención)
- Tráfico < threshold
- Solo logging
- **Impacto en jugadores: 0%**

### Nivel 2: Análisis (Threshold excedido)
- Análisis de patrón activado
- Si es legítimo: NO mitigar
- Si es ataque: Continuar a Nivel 3
- **Impacto en jugadores: 0-5%** (lag mínimo por análisis)

### Nivel 3: Mitigación Selectiva
- Banear top 20% IPs atacantes
- Rate limiting permisivo (1500 PPS)
- **Impacto en jugadores: 5-15%** (lag leve)

### Nivel 4: Mitigación Agresiva
- Banear IPs con >20 conexiones
- Rate limiting restrictivo (750 PPS)
- **Impacto en jugadores: 15-30%** (lag moderado)

### Nivel 5: Protección Extrema
- Bloqueo total del puerto
- Solo en ataques >10k PPS
- **Impacto en jugadores: 100%** (servicio inaccesible temporalmente)

## 🔍 Logs y Diagnóstico

### Log de Tráfico Normal

```
[INFO] Traffic: 1200 PPS, 15 Mbps (20 players)
[DEBUG] Pattern: legitimate traffic, 20 unique IPs
```

### Log de Gaming Intenso

```
[INFO] High traffic on Minecraft: 3500 PPS, 100 players
[DEBUG] Legitimate pattern: only 100 unique IPs
[DEBUG] High traffic but legitimate: 100 IPs, avg 2.0 conn/IP, 3500 PPS
[INFO] Threshold exceeded but NO ATTACK DETECTED - allowing traffic
```

### Log de Ataque Detectado

```
[WARNING] High traffic on Minecraft: 5500 PPS, 250 unique IPs
[WARNING] Attack pattern detected: 60/250 suspicious IPs (avg: 8.5, max: 45)
[WARNING] 50 attacker IPs blocked in Minecraft (attack confirmed)
[WARNING] Mitigation applied to Minecraft: Rate limit 1500 PPS
[INFO] Discord notification sent: Service attack detected
```

### Log de Ataque Masivo

```
[WARNING] Massive UDP attack detected on Minecraft: 8500 PPS
[WARNING] Attack pattern: 400+ unique IPs, high PPS/IP
[WARNING] 80 IPs blocked for massive UDP attack
[WARNING] SEVERE attack: applying restrictive rate limit (750 PPS)
[CRITICAL] EXTREME ATTACK: 12000 PPS on Minecraft
[CRITICAL] Port 25565/udp blocked (extreme attack protection)
```

## ✅ Verificación del Sistema

### Test 1: Gaming Normal No Bloquea

```bash
# 20 jugadores conectando
# Verificar que NO hay mitigación
sudo journalctl -u antiddos-monitor | grep "legitimate"
# Debe mostrar: "Legitimate pattern" o "High traffic but legitimate"
```

### Test 2: Ataque Se Detecta

```bash
# Simular ataque (NO recomendado en producción)
# Verificar logs
sudo journalctl -u antiddos-monitor | grep -i "attack"
# Debe mostrar: "Attack pattern detected"
```

### Test 3: Whitelist Protege

```bash
# IP en whitelist con alto tráfico
# Verificar que NO se banea
sudo journalctl -u antiddos-monitor | grep "whitelist"
# Debe mostrar: "IP X.X.X.X in whitelist - not blocking"
```

## 📋 Resumen de Protecciones

| Protección | Threshold | Impacto Gaming | Efectividad Anti-DDoS |
|------------|-----------|----------------|----------------------|
| **Análisis de Patrones** | Automático | 0% | ⭐⭐⭐⭐⭐ (clave) |
| **Blacklist Top 20%** | 30+ conn | 0% | ⭐⭐⭐⭐ |
| **Rate Limiting** | 1500 PPS | 5-15% | ⭐⭐⭐⭐ |
| **UDP Selective Ban** | 5000 PPS | 10-20% | ⭐⭐⭐⭐⭐ |
| **Port Block** | 10000 PPS | 100% | ⭐⭐⭐⭐⭐ |
| **Global Mitigation** | 200 Mbps | 20-40% | ⭐⭐⭐⭐⭐ |
| **Filtrado País** | Durante ataque | 0-10% | ⭐⭐⭐ |

## 🎯 Conclusión

El sistema ahora implementa una **protección inteligente escalonada**:

1. ✅ **Gaming legítimo fluye libremente** - No hay intervención
2. ⚠️ **Tráfico alto analizado** - Determina si es ataque
3. 🎯 **Ataques mitigados selectivamente** - Banea atacantes, no jugadores
4. 🛡️ **Protección extrema solo cuando es necesario** - Último recurso
5. 🌍 **Mitigación global para ataques masivos** - Protege infraestructura

**Balance perfecto entre protección y usabilidad.**

---

**Última actualización**: 2024-11-21  
**Versión**: 1.0.3  
**Estado**: Optimizado para Gaming + DDoS Protection
