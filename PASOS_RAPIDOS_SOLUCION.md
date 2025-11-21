# ⚡ SOLUCIÓN RÁPIDA - Desconexiones de Jugadores

## 🚨 PROBLEMA DETECTADO

**Las reglas de firewall NO se limpian cuando detienes el servicio antiddos**, causando que los jugadores se desconecten incluso con el servicio "desactivado".

## ✅ SOLUCIÓN INMEDIATA (5 minutos)

### Paso 1: Limpiar Reglas Residuales

```bash
cd /opt/anti-ddos
sudo chmod +x scripts/fix-gaming-disconnects.sh
sudo bash scripts/fix-gaming-disconnects.sh
```

✅ Este script elimina TODAS las reglas ANTIDDOS que están bloqueando jugadores.

### Paso 2: Probar Conexión

**Después del script, prueba que los jugadores puedan conectar.**

- ✅ **Si funciona**: El problema era las reglas residuales → Continúa al Paso 3
- ❌ **Si NO funciona**: El problema NO es el firewall → Ver sección "Otros Problemas" abajo

### Paso 3: Actualizar el Código

```bash
cd /opt/anti-ddos

# Hacer backup
sudo cp -r /opt/anti-ddos /opt/anti-ddos.backup

# Actualizar código (pull de Git o copiar archivos editados)
sudo pip3 install -e . --force-reinstall
```

### Paso 4: Actualizar Configuración

```bash
# Backup de config
sudo cp /etc/antiddos/config.yaml /etc/antiddos/config.yaml.backup

# Copiar nueva config
sudo cp config/config.yaml /etc/antiddos/config.yaml

# IMPORTANTE: Restaurar tus IPs whitelisted
sudo nano /etc/antiddos/config.yaml
# Buscar la sección 'whitelist:' y agregar tus IPs
```

### Paso 5: Reiniciar Servicio

```bash
# Iniciar con nueva configuración
sudo systemctl start antiddos-monitor

# Monitorear logs
sudo journalctl -u antiddos-monitor -f
```

Deberías ver:
```
Anti-DDoS Monitor starting
Applying DoS filters (Pterodactyl traffic bypassed)
UDP flood protection: global limit 1000/s (permisivo para gaming)
```

### Paso 6: Verificar que NO Bloquea Gaming

```bash
# Ver reglas UDP
sudo iptables -L ANTIDDOS -n -v | grep udp

# Debe mostrar límite alto (1000/s):
# ... limit: avg 1000/sec burst 2000 ...
```

✅ **Prueba conectar jugadores - deben poder jugar sin desconexiones**

## 🔍 VERIFICACIÓN DEL FIX

### Test 1: Cleanup Funciona

```bash
# Detener servicio
sudo systemctl stop antiddos-monitor

# Verificar que NO quedan reglas
sudo iptables -L ANTIDDOS -n

# Debe dar error: "No chain/target/match by that name"
# ✅ Esto confirma que el cleanup funciona correctamente
```

### Test 2: Reglas Son Permisivas

```bash
# Iniciar servicio
sudo systemctl start antiddos-monitor

# Ver límites UDP
sudo iptables -L ANTIDDOS -n -v | grep -A2 "udp"

# Verificar:
# ✅ Límite global: 1000/s (o más)
# ✅ NO debe haber reglas DROP para UDP después del límite
```

### Test 3: Jugadores Conectan

```bash
# Desde el servidor
nc -zv 127.0.0.1 25565  # Minecraft Java
nc -zv 127.0.0.1 19132  # Minecraft Bedrock

# Desde un jugador externo
# Conectar normalmente y jugar 10+ minutos
# ✅ No debe haber desconexiones
```

## 📋 CAMBIOS REALIZADOS

### 1. Fix en `monitor.py`

**Antes (DEFECTUOSO):**
```python
def stop(self):
    self.running = False
    sys.exit(0)  # ❌ No limpia reglas
```

**Después (ARREGLADO):**
```python
def stop(self):
    self.running = False
    self.firewall.cleanup()  # ✅ Limpia reglas
    sys.exit(0)
```

### 2. Fix en `firewall.py` - Cleanup Mejorado

- Elimina saltos de INPUT, FORWARD y OUTPUT
- Limpia TODAS las cadenas ANTIDDOS_*
- Loop hasta eliminar todas las instancias

### 3. Fix en `firewall.py` - Filtros DoS Optimizados

**Antes (DEMASIADO RESTRICTIVO):**
- UDP: 80-100 PPS → DROP
- Límite global para TODO el tráfico
- Bloqueaba jugadores legítimos

**Después (OPTIMIZADO PARA GAMING):**
- UDP: 1000 PPS → ACCEPT (10x más permisivo)
- Sin límite por IP para UDP
- NO DROP después del límite
- Solo aplica a tráfico NO-Docker

### 4. Fix en `config.yaml`

```yaml
# Valores ANTES → DESPUÉS

dos_filter:
  syn_flood:
    threshold: 40 → 100
  udp_flood:
    threshold: 80 → 100 (límite global: 1000/s)
  connection_limit:
    max_connections: 40 → 100

services:
  default_threshold_pps: 500 → 1000
  default_threshold_mbps: 8 → 15
  window_seconds: 5 → 10
  auto_rate_limit:
    enabled: true → false  # ❌ Causaba lag
  auto_udp_block:
    enabled: true → false  # ❌ Bloqueaba Minecraft
  auto_blacklist:
    min_connections: 10 → 50
```

## ⚠️ OTROS PROBLEMAS POSIBLES

Si después del fix los jugadores SIGUEN sin poder conectar, el problema NO es el firewall. Verifica:

### 1. Wings no está corriendo

```bash
sudo systemctl status wings

# Si está detenido:
sudo systemctl start wings
sudo journalctl -u wings -f
```

### 2. Contenedores no están corriendo

```bash
docker ps

# Si no hay contenedores, inícialos desde el panel Pterodactyl
```

### 3. Puertos no están escuchando

```bash
sudo ss -tulnp | grep -E "25565|19132"

# Si no muestra nada, el servidor no está escuchando
```

### 4. NAT de Docker no está configurado

```bash
sudo iptables -t nat -L DOCKER -n

# Debe mostrar reglas DNAT para los puertos
# Si está vacío:
sudo systemctl restart docker
sudo systemctl restart wings
```

### 5. Firewall externo (UFW, firewalld)

```bash
# UFW
sudo ufw status
# Si está activo, permitir puertos:
sudo ufw allow 25565/tcp
sudo ufw allow 25565/udp
sudo ufw allow 19132/udp

# Firewalld
sudo firewall-cmd --list-all
```

## 📞 SOPORTE

Si después de aplicar TODOS estos pasos sigues con problemas:

1. **Recolectar información:**

```bash
# Ejecutar diagnóstico
sudo bash scripts/diagnose.sh > diagnostico.txt

# Ver logs
sudo journalctl -u antiddos-monitor -n 100 > antiddos.log
sudo journalctl -u wings -n 100 > wings.log
sudo journalctl -u docker -n 100 > docker.log

# Ver reglas
sudo iptables -L -n -v > iptables.txt
sudo iptables -t nat -L -n -v > iptables-nat.txt
```

2. **Información del servidor:**
   - Sistema operativo y versión
   - Versión de Docker
   - Versión de Wings
   - Tipo de juego (Minecraft Java/Bedrock, etc.)
   - ¿Los jugadores son locales o remotos?
   - ¿El error es al conectar o después de conectar?

## 🛡️ PROTECCIÓN BALANCEADA

El sistema ahora implementa **detección inteligente de ataques**:

### Gaming Legítimo (No Intervención)
- ✅ 10-100 jugadores: **PERMITIDO** sin restricciones
- ✅ Análisis automático de patrones
- ✅ NO banea jugadores con tráfico normal
- ✅ Rate limiting SOLO si ataque confirmado

### Ataque DDoS Real (Mitigación Activa)
- 🎯 Detecta patrones de botnet (muchas IPs, distribución anormal)
- 🎯 Banea solo top 20% de IPs atacantes
- 🎯 Rate limiting escalonado (más restrictivo en ataques severos)
- 🎯 Bloqueo total solo para ataques >10k PPS (extremos)

### Thresholds Configurados
- **Por servicio**: 2000 PPS, 20 Mbps (permite 50+ jugadores)
- **UDP blocking**: Solo ataques >5000 PPS (masivos)
- **Auto-blacklist**: 30+ conexiones simultáneas por IP
- **Global**: 200 Mbps / 50k PPS activa mitigación global

**Ver documentación completa**: `docs/BALANCED_PROTECTION.md`

## 🎯 RESUMEN

1. ✅ Ejecutar `fix-gaming-disconnects.sh` para limpiar reglas
2. ✅ Verificar que jugadores pueden conectar sin ANTIDDOS
3. ✅ Actualizar código y configuración (incluye detección inteligente)
4. ✅ Reiniciar servicio con nueva configuración
5. ✅ Verificar que cleanup funciona al detener servicio
6. ✅ Probar que jugadores pueden jugar sin desconexiones
7. ✅ Sistema protege contra ataques DDoS reales

**Tiempo estimado: 5-10 minutos**
**Protección: ⭐⭐⭐⭐⭐ Gaming + Anti-DDoS**

---

**Última actualización**: 2024-11-21  
**Criticidad**: ⚠️ ALTA - Aplica inmediatamente
