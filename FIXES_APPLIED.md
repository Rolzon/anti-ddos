# Reparaciones Aplicadas al Sistema Anti-DDoS

## ❌ Problemas Identificados

### 1. **IPs Atacantes NO se Bloqueaban**
- **Causa raíz**: Umbrales extremadamente altos
  - `min_connections: 100` - Requería 100 conexiones simultáneas (imposible para muchos atacantes)
  - `min_pps: 1200` - PPS muy alto, ataque ya había causado daño
  - `ban_connection_threshold: 1` - Demasiado bajo, causaba false positives

### 2. **Orden Incorrecto de Mitigación**
- **Problema**: Bloqueaba el puerto COMPLETO antes de intentar banear IPs específicas
- **Efecto**: Servicio caía para todos (legítimos + atacantes)
- **Causa**: Lógica de `auto_udp_block` ejecutaba ANTES de `auto_blacklist`

### 3. **Detección Limitada**
- **Problema**: Solo contaba conexiones TCP establecidas
- **Efecto**: Ataques UDP (Minecraft) no generaban "conexiones" suficientes para detectar
- **Faltaba**: Logging detallado de atacantes detectados

---

## ✅ Reparaciones Aplicadas

### A. Ajustes de Configuración (@config/config.yaml)

#### **1. Umbrales Equilibrados** (Líneas 122-139)
```yaml
# ANTES (demasiado permisivo)
default_threshold_pps: 600
min_connections: 100        # ← Extremadamente alto
min_pps: 1200              # ← Muy alto
ban_connection_threshold: 1 # ← Muy bajo (false positives)

# DESPUÉS (equilibrado)
default_threshold_pps: 500  # Detección más temprana
min_connections: 10         # ✅ CRÍTICO: 10 conexiones simultáneas
min_pps: 800               # ✅ Reducido para captura temprana
ban_connection_threshold: 5 # ✅ Equilibrado: 5 conexiones durante ataque
ban_duration_seconds: 3600  # ✅ 1 hora (era 30 min)
```

**Por qué funciona mejor:**
- `min_connections: 10` → Detecta bots individuales (realista)
- `ban_connection_threshold: 5` → Balance entre falsos positivos y detección
- `min_pps: 800` → Captura ataques antes de saturar red

---

### B. Reordenamiento de Lógica de Mitigación (@src/antiddos/monitor.py)

#### **ANTES** (orden incorrecto):
```
1. Rate limiting (PPS limit)
2. Bloquear puerto UDP completo
3. Banear IPs atacantes  ← Demasiado tarde
```

#### **DESPUÉS** (orden correcto - Líneas 309-379):
```python
# PASO 1: BANEAR IPS ATACANTES PRIMERO
# → Bloquea atacantes específicos (min_connections: 10)
# → Menos disruptivo, jugadores legítimos continúan

# PASO 2: Para UDP, banear IPs con menos conexiones
# → Si ataque es intenso, umbral más bajo (ban_connection_threshold: 5)
# → Captura floods distribuidos

# PASO 3: Rate limiting al puerto
# → Limita PPS del puerto (limit_pps: 400)
# → Jugadores legítimos con lag, pero conectados

# PASO 4: ÚLTIMO RECURSO - Bloquear puerto completo
# → Solo si PPS >= 800 Y ya intentamos banear IPs
# → Protege servidor de colapso total
```

**Beneficio clave:**
- ✅ Bloquea atacantes específicos ANTES de afectar servicio completo
- ✅ Jugadores legítimos mantienen conexión mientras se neutraliza ataque
- ✅ Menos "downtime" del servidor

---

### C. Logging Mejorado (@src/antiddos/monitor.py líneas 386-396)

**Añadido:**
```python
# Log con métricas detalladas
self.logger.warning(
    f"Tráfico elevado: {stats.total_mbps:.2f} Mbps / {stats.total_pps} PPS | "
    f"Conexiones: {stats.connections} | Top atacantes: {len(stats.top_attackers)}"
)

# Log de atacantes individuales
attacker_summary = ", ".join([f"{ip}({conns})" for ip, conns in stats.top_attackers[:3]])
self.logger.info(f"Top atacantes: {attacker_summary}")
```

**Ahora verás en logs:**
```
[WARNING] Tráfico elevado en MC-Server: 7.8 Mbps / 523 PPS | Conexiones: 45 | Top atacantes: 3
[INFO] Top atacantes en MC-Server: 1.2.3.4(12), 5.6.7.8(9), 9.10.11.12(7)
[WARNING] Mitigación aplicada: IP 1.2.3.4 bloqueada (12 conexiones)
```

---

### D. Integración FORWARD Chain (Ya aplicado previamente)

**Verificación rápida:**
```bash
# Las IPs bloqueadas DEBEN aparecer en FORWARD (Docker)
sudo iptables -L FORWARD -n -v | head -20
```

**Debe mostrar:**
```
Chain FORWARD (policy ACCEPT)
1    DROP  all  --  *  *  1.2.3.4  0.0.0.0/0  # ← IP bloqueada
2    ANTIDDOS all --  *  *  0.0.0.0/0  0.0.0.0/0  # ← Cadena anti-DDoS
```

---

## 🧪 Cómo Validar que Funciona

### 1. **Antes de Reinstalar - Desinstalar limpio**
```bash
cd /opt/anti-ddos
sudo ./uninstall.sh
# Responde 'y' para eliminar configuración antigua
```

### 2. **Reinstalar con Configuración Corregida**
```bash
cd /opt/anti-ddos
sudo ./reinstall.sh
```

### 3. **Verificar Configuración Aplicada**
```bash
# Verificar umbrales corregidos
grep -A 3 "min_connections:" /etc/antiddos/config.yaml
# Debe mostrar: min_connections: 10

grep -A 3 "auto_udp_block:" /etc/antiddos/config.yaml
# Debe mostrar: min_pps: 800 y ban_connection_threshold: 5
```

### 4. **Monitorear Logs en Tiempo Real**
```bash
# Ver detección y bloqueos
sudo journalctl -u antiddos-monitor -f | grep -E "bloqueada|atacantes|Mitigación"
```

**Deberías ver:**
```
Top atacantes en docker-abc123-25565: 1.2.3.4(12), 5.6.7.8(9)
IP 1.2.3.4 bloqueada (12 conexiones)
Mitigación aplicada a docker-abc123-25565: IP 1.2.3.4 bloqueada (12 conexiones)
```

### 5. **Verificar IPs Bloqueadas en Firewall**
```bash
# Ver reglas ANTIDDOS
sudo iptables -L ANTIDDOS -n -v --line-numbers | grep DROP

# Ver IPs bloqueadas en FORWARD (crítico para Docker)
sudo iptables -L FORWARD -n -v | grep DROP | head -10
```

**Debe mostrar IPs bloqueadas:**
```
1    123  DROP  all  --  *  *  1.2.3.4  0.0.0.0/0
2    456  DROP  all  --  *  *  5.6.7.8  0.0.0.0/0
```

### 6. **Ver Estado de Servicios**
```bash
antiddos status
```

**Debe listar:**
- Servicios Docker descubiertos
- Interfaces asignadas (dr0 o vethXXX)
- Umbrales configurados

---

## 📊 Comparación Antes vs Después

| Métrica | ANTES (No Funcionaba) | DESPUÉS (Corregido) |
|---------|----------------------|---------------------|
| **Min conexiones para ban** | 100 🔴 | 10 ✅ |
| **Min PPS UDP** | 1200 🔴 | 800 ✅ |
| **Ban threshold UDP** | 1 🔴 | 5 ✅ |
| **Duración del ban** | 30 min 🟡 | 60 min ✅ |
| **Orden de mitigación** | Puerto → IPs 🔴 | IPs → Puerto ✅ |
| **Bloqueo FORWARD** | ❌ | ✅ |
| **Logging atacantes** | ❌ | ✅ |

---

## 🚨 Señales de que Está Funcionando

### ✅ Logs Correctos:
```
[INFO] Bloqueadas 3 IPs atacantes en docker-abc123-25565
[INFO] Top atacantes: 1.2.3.4(12), 5.6.7.8(9), 9.10.11.12(7)
[WARNING] IP 1.2.3.4 bloqueada (12 conexiones)
```

### ✅ iptables Tiene Reglas:
```bash
sudo iptables -L ANTIDDOS -n | wc -l
# Si es > 5, significa que hay IPs bloqueadas
```

### ✅ Discord Notifica:
- Mensaje "⛔ IP bloqueada" con detalles
- Embed con IP, razón, duración

### ❌ Logs Incorrectos (No detecta):
```
[WARNING] Tráfico elevado: 8.2 Mbps / 650 PPS | Conexiones: 2 | Top atacantes: 0
# ← Si conexiones es bajo pero PPS alto, revisar psutil.net_connections()
```

---

## 🔧 Troubleshooting

### Problema: "No se detectan atacantes"
```bash
# Verificar que psutil puede leer conexiones
sudo python3 -c "import psutil; print(len(psutil.net_connections()))"
# Debe mostrar número > 0
```

**Solución si falla:**
```bash
# Instalar dependencias de psutil
sudo apt install -y python3-dev gcc
sudo pip3 install --upgrade psutil
sudo systemctl restart antiddos-monitor
```

### Problema: "IPs no se bloquean en FORWARD"
```bash
# Verificar que FORWARD tiene ANTIDDOS
sudo iptables -L FORWARD -n | grep ANTIDDOS
```

**Si no aparece:**
```bash
sudo systemctl restart antiddos-monitor
# El servicio crea las reglas en initialize()
```

### Problema: "Muchos falsos positivos"
```yaml
# Aumentar umbral en /etc/antiddos/config.yaml
auto_blacklist:
  min_connections: 15  # Subir de 10 a 15
ban_connection_threshold: 8  # Subir de 5 a 8
```

---

## 📝 Resumen de Archivos Modificados

1. **config/config.yaml** (Líneas 122-139)
   - `default_threshold_pps: 500` (era 600)
   - `min_connections: 10` (era 100) ← **CRÍTICO**
   - `min_pps: 800` (era 1200)
   - `ban_connection_threshold: 5` (era 1)
   - `ban_duration_seconds: 3600` (era 1800)

2. **src/antiddos/monitor.py** (Líneas 309-398)
   - Reordenó lógica: IPs primero, puerto al final
   - Añadió logging detallado de atacantes
   - Evita duplicados en bloqueo

3. **src/antiddos/firewall.py** (Previamente corregido)
   - ANTIDDOS chain en FORWARD (Docker)
   - `block_ip()` bloquea en INPUT + FORWARD
   - `unblock_ip()` limpia ambas cadenas

---

## ✨ Beneficios Finales

1. ✅ **IPs atacantes se bloquean automáticamente** (umbral realista: 10 conexiones)
2. ✅ **Detección temprana** (PPS: 800 en lugar de 1200)
3. ✅ **Menos downtime** (bloquea atacantes antes que puerto completo)
4. ✅ **Whitelist respetada** (IPs confiables nunca bloqueadas)
5. ✅ **Compatible con Docker/Wings** (reglas en FORWARD + INPUT)
6. ✅ **Logging detallado** (puedes ver exactamente qué IPs se bloquean)
7. ✅ **Balance de falsos positivos** (ban_threshold: 5 es equilibrado)

---

## 📞 Si Aún No Funciona

Ejecuta este comando y comparte la salida:

```bash
echo "=== DIAGNÓSTICO COMPLETO ===" && \
echo "1. Config:" && grep -E "min_connections|min_pps|ban_connection" /etc/antiddos/config.yaml && \
echo "2. Servicio:" && systemctl status antiddos-monitor --no-pager && \
echo "3. Reglas FORWARD:" && sudo iptables -L FORWARD -n | head -10 && \
echo "4. Reglas ANTIDDOS:" && sudo iptables -L ANTIDDOS -n | head -10 && \
echo "5. Últimos logs:" && sudo journalctl -u antiddos-monitor -n 20 --no-pager
```

Esto mostrará si:
- Configuración está aplicada ✅
- Servicio está corriendo ✅
- Reglas existen en firewall ✅
- Logs muestran detección ✅
