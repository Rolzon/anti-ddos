# Instalación de Mejoras Gaming v2.0

**IMPORTANTE:** Sigue estos pasos en orden para instalar las mejoras sin causar interrupciones.

---

## ⚡ Instalación Rápida (5 minutos)

```bash
cd /opt/anti-ddos

# 1. Detener servicio (evita conflictos)
sudo systemctl stop antiddos-monitor

# 2. Instalar código mejorado
sudo pip3 install -e .

# 3. Actualizar configuración
sudo cp config/config.yaml /etc/antiddos/config.yaml

# 4. Validar configuración
sudo bash scripts/test-gaming-config.sh

# 5. Iniciar servicio
sudo systemctl start antiddos-monitor

# 6. Monitorear logs
sudo journalctl -u antiddos-monitor -f
```

---

## 📋 Instalación Paso a Paso (Detallada)

### Paso 0: Backup de Configuración Actual

```bash
# Crear backup de config actual (por si acaso)
sudo cp /etc/antiddos/config.yaml /etc/antiddos/config.yaml.backup.$(date +%Y%m%d)

# Crear backup de blacklist
sudo cp /etc/antiddos/blacklist.txt /etc/antiddos/blacklist.txt.backup.$(date +%Y%m%d)

echo "✅ Backups creados en /etc/antiddos/"
```

### Paso 1: Verificar Estado Actual

```bash
# Ver si el servicio está activo
sudo systemctl status antiddos-monitor

# Ver última actividad
sudo journalctl -u antiddos-monitor --since "10 minutes ago" | tail -20

# Ver reglas firewall actuales
sudo nft list table ip filter | grep ANTIDDOS | wc -l
```

### Paso 2: Detener Servicio Temporalmente

```bash
# Detener servicio (limpia reglas firewall automáticamente)
sudo systemctl stop antiddos-monitor

# Verificar que se detuvo
sudo systemctl status antiddos-monitor | grep "inactive"

# Verificar que reglas ANTIDDOS fueron limpiadas
sudo nft list table ip filter | grep ANTIDDOS
# No debe mostrar nada
```

### Paso 3: Actualizar Código

```bash
cd /opt/anti-ddos

# Verificar que estamos en el directorio correcto
pwd
# Debe mostrar: /opt/anti-ddos

# Actualizar código Python
sudo pip3 install -e .

# Verificar instalación
python3 -c "from antiddos.monitor import AntiDDoSMonitor; print('✅ Código instalado correctamente')"
```

### Paso 4: Actualizar Configuración

**Opción A: Usar configuración nueva completa (Recomendado para servidores Minecraft)**

```bash
# Copiar configuración optimizada para Minecraft
sudo cp config/config-minecraft-optimized.yaml /etc/antiddos/config.yaml

# IMPORTANTE: Editar y personalizar
sudo nano /etc/antiddos/config.yaml

# Cosas a cambiar:
# - bandwidth.interface: dr0 → tu interfaz (ver con: ip link)
# - whitelist.ips: Agregar tu IP pública
# - notifications.discord.webhook_url: Tu webhook de Discord
# - advanced.mysql.server_public_ip: Tu IP pública
```

**Opción B: Actualizar configuración existente manualmente**

```bash
sudo nano /etc/antiddos/config.yaml

# Cambiar estos valores:
# services.default_threshold_pps: 3500
# services.default_threshold_mbps: 30
# services.auto_rate_limit.limit_pps: 3000
# services.auto_udp_block.min_pps: 8000
# services.auto_udp_block.ban_connection_threshold: 50
# services.auto_blacklist.min_connections: 60
# dos_filter.syn_flood.threshold: 150
# dos_filter.udp_flood.threshold: 150
# dos_filter.connection_limit.max_connections: 150
```

### Paso 5: Validar Configuración

```bash
# Ejecutar script de validación
sudo bash scripts/test-gaming-config.sh

# Debe mostrar:
# ✅ Configuración PERFECTA para gaming servers!
# o
# ⚠️ Configuración FUNCIONAL con advertencias menores
```

**Si hay errores:**

```bash
# Ver errores específicos
sudo bash scripts/test-gaming-config.sh 2>&1 | grep "ERROR"

# Corregir en el archivo de config
sudo nano /etc/antiddos/config.yaml

# Re-validar
sudo bash scripts/test-gaming-config.sh
```

### Paso 6: Verificar Código Actualizado

```bash
# Verificar que el código tiene las mejoras
grep -n "is_gaming_port" /opt/anti-ddos/src/antiddos/monitor.py

# Debe mostrar algo como:
# 327:        is_gaming_port = False
# 328:        if hasattr(stats, 'service') and stats.service.port:
# ...

# Verificar análisis estadístico
grep -n "std_dev" /opt/anti-ddos/src/antiddos/monitor.py

# Debe mostrar líneas con cálculo de desviación estándar
```

### Paso 7: Iniciar Servicio

```bash
# Iniciar servicio con nuevas mejoras
sudo systemctl start antiddos-monitor

# Verificar que inició correctamente
sudo systemctl status antiddos-monitor

# Debe mostrar:
# ● antiddos-monitor.service - Anti-DDoS Monitoring Service
#    Loaded: loaded
#    Active: active (running)
```

### Paso 8: Monitorear Inicialización

```bash
# Ver logs de inicialización
sudo journalctl -u antiddos-monitor -n 50

# Buscar estas líneas (indican inicialización correcta):
# ✅ "Using iptables binary: iptables-nft"
# ✅ "Initializing firewall rules (nft compatible)"
# ✅ "Service-level monitoring enabled"
# ✅ "Anti-DDoS Monitor started"
```

### Paso 9: Monitoreo en Tiempo Real (15 minutos)

```bash
# Ver logs en vivo
sudo journalctl -u antiddos-monitor -f

# Deberías ver:
# ✅ "Patrón legítimo: solo X IPs únicas" → Jugadores detectados correctamente
# ✅ "Tráfico alto pero patrón legítimo" → Sistema funcionando bien
# ⚠️ "Patrón de ataque detectado" → Solo si hay ataque REAL

# Presionar Ctrl+C para salir
```

### Paso 10: Verificar Jugadores NO Desconectados

```bash
# Ver estadísticas de servicios
cat /var/run/antiddos/service_stats.json | jq '.services[] | {name, pps_in, pps_out, connections, mitigation}'

# Verificar que mitigation = false para todos los servicios
# Si mitigation = true, revisar logs para ver por qué

# Ver IPs bloqueadas (debe estar vacío si no hay ataques)
wc -l /etc/antiddos/blacklist.txt
```

---

## 🧪 Testing de 1 Hora

Durante 1 hora, monitorea lo siguiente:

### 1. Logs del servicio

```bash
# Terminal 1: Logs en vivo
sudo journalctl -u antiddos-monitor -f
```

### 2. Estadísticas de servicios

```bash
# Terminal 2: Ver cada 30 segundos
watch -n 30 'cat /var/run/antiddos/service_stats.json | jq ".services[] | {name, pps_in, connections, mitigation}"'
```

### 3. Jugadores conectados

```bash
# Verificar que jugadores NO se desconectan
# Pedirles que jueguen normalmente por 15-30 minutos
```

### Métricas de éxito:

- ✅ `mitigation: false` en todos los servicios
- ✅ Logs muestran "Patrón legítimo" frecuentemente
- ✅ Jugadores NO se desconectan
- ✅ NO hay IPs legítimas en `/etc/antiddos/blacklist.txt`

---

## 🔧 Troubleshooting

### Problema 1: Servicio no inicia

```bash
# Ver error exacto
sudo journalctl -u antiddos-monitor -n 50 --no-pager

# Errores comunes:
# - "ModuleNotFoundError": pip3 install -e . no se ejecutó
# - "FileNotFoundError config.yaml": Archivo de config no existe
# - "Permission denied": Ejecutar con sudo
```

**Solución:**
```bash
cd /opt/anti-ddos
sudo pip3 install -e .
sudo cp config/config-minecraft-optimized.yaml /etc/antiddos/config.yaml
sudo systemctl restart antiddos-monitor
```

### Problema 2: Jugadores aún desconectados

```bash
# Ver qué está pasando
sudo journalctl -u antiddos-monitor -f | grep -E "(Patrón|bloqueada|Rate limit)"

# Si ves "Patrón de ataque detectado" para tráfico legítimo:
# → Aumentar thresholds

sudo nano /etc/antiddos/config.yaml
# Cambiar:
# default_threshold_pps: 5000  (de 3500 a 5000)
# auto_blacklist.min_connections: 80  (de 60 a 80)

sudo systemctl restart antiddos-monitor
```

### Problema 3: Muchas IPs bloqueadas

```bash
# Ver IPs bloqueadas
cat /etc/antiddos/blacklist.txt

# Si hay IPs legítimas:
# 1. Desbloquear IP específica
sudo nano /etc/antiddos/blacklist.txt
# Eliminar línea de la IP

# 2. Agregar a whitelist
sudo nano /etc/antiddos/config.yaml
# En whitelist.ips agregar la IP

# 3. Reiniciar
sudo systemctl restart antiddos-monitor
```

### Problema 4: Logs no muestran detecciones

```bash
# Verificar que hay tráfico
sudo docker ps
sudo ss -tulnp | grep -E "19[0-9]{3}|20[0-9]{3}"

# Verificar interfaz correcta
ip link
# Cambiar en config si es necesario:
sudo nano /etc/antiddos/config.yaml
# bandwidth.interface: <tu_interfaz>
# services.default_interface: <tu_interfaz>

sudo systemctl restart antiddos-monitor
```

---

## 📊 Validación Final (Después de 24 horas)

### Checklist:

- [ ] Servicio corriendo 24 horas sin errores
- [ ] Jugadores jugando sin desconexiones
- [ ] Logs muestran detecciones legítimas correctamente
- [ ] NO hay IPs legítimas bloqueadas
- [ ] Notificaciones Discord funcionando (si configuradas)
- [ ] Al menos 1 alerta de ataque real bloqueado (si hubo ataque)

### Comandos de validación:

```bash
# 1. Uptime del servicio
sudo systemctl status antiddos-monitor | grep "Active:"
# Debe mostrar: active (running) since [fecha hace 24h]

# 2. Estadísticas de detecciones
sudo journalctl -u antiddos-monitor --since "24 hours ago" | grep "Patrón legítimo" | wc -l
# Debe ser > 0 si hubo tráfico

# 3. Ataques bloqueados
sudo journalctl -u antiddos-monitor --since "24 hours ago" | grep "Patrón de ataque" | wc -l
# Debe ser 0 (sin ataques) o >0 (ataques bloqueados correctamente)

# 4. IPs bloqueadas
wc -l /etc/antiddos/blacklist.txt
# Debe ser 0 o solo IPs maliciosas conocidas

# 5. Errores en logs
sudo journalctl -u antiddos-monitor --since "24 hours ago" -p err | wc -l
# Debe ser 0
```

---

## ✅ Instalación Completada

Si todos los tests pasaron, ¡felicidades! El sistema está correctamente instalado y optimizado.

### Próximos pasos:

1. **Documentación:** Leer `docs/GAMING_SERVERS_GUIDE.md` para configuraciones avanzadas
2. **Ajustes:** Si tienes un servidor muy grande (80+ jugadores), ajustar thresholds
3. **Monitoreo:** Configurar notificaciones Discord para recibir alertas
4. **Mantenimiento:** Revisar logs semanalmente para ajustes finos

### Soporte:

Si tienes problemas, exportar logs:

```bash
sudo journalctl -u antiddos-monitor --since "2 hours ago" > antiddos-debug.log
cat /etc/antiddos/config.yaml > config-current.yaml
sudo nft list table ip filter > firewall-rules.txt
```

---

**Versión:** 2.0 Gaming-Optimized  
**Fecha:** 2024-11-21
