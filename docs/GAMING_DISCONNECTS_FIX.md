# Solución: Jugadores se Desconectan en Servidores de Pterodactyl

## 🚨 Problema Identificado

Los jugadores se desconectan a los segundos de entrar a los servidores de Minecraft/Gaming, **incluso con el servicio antiddos desactivado**.

## 🔍 Causa Raíz

### Problema #1: Reglas de Firewall NO se Limpiaban al Detener el Servicio

**Código anterior en `monitor.py` (DEFECTUOSO):**

```python
def stop(self):
    """Stop the monitoring daemon"""
    self.running = False
    self.logger.info("Anti-DDoS Monitor stopped")
    sys.exit(0)
```

❌ **NO llamaba a `self.firewall.cleanup()`**

**Resultado**: Al ejecutar `systemctl stop antiddos-monitor`, el proceso se detenía PERO las reglas de iptables seguían activas, bloqueando conexiones.

### Problema #2: Filtros DoS Demasiado Agresivos

**Filtros UDP anteriores (DEFECTUOSOS):**

```python
# UDP flood protection - ANTIGUO
threshold = self.config.get('dos_filter.udp_flood.threshold', 100)
# Aplicaba límite de 100 PPS por IP - DEMASIADO BAJO
self.run_command([..., '-m', 'limit', '--limit', f'{threshold}/s', ...])
# Luego DROP de todo lo que excedía
self.run_command([..., '-j', 'DROP'])
```

❌ **Problemas**:
- Límite de 80-100 PPS para UDP es extremadamente bajo
- Un jugador de Minecraft Bedrock puede generar 100-300 PPS fácilmente
- El DROP estaba bloqueando tráfico legítimo

### Problema #3: Rate Limiting Automático en Servicios

**Configuración anterior (DEFECTIVA):**

```yaml
services:
  auto_rate_limit:
    enabled: true      # ❌ Causaba lag
    limit_pps: 400
  auto_udp_block:
    enabled: true      # ❌ Bloqueaba Minecraft
    min_pps: 800
```

Cuando un servidor tenía picos de tráfico normales (por ejemplo, 10 jugadores uniéndose al mismo tiempo), el sistema:
1. Detectaba "ataque"
2. Aplicaba rate limiting
3. Bloqueaba IPs con pocas conexiones
4. **Desconectaba a jugadores legítimos**

## ✅ Soluciones Implementadas

### Solución #1: Cleanup Apropiado al Detener Servicio

**Nuevo código en `monitor.py`:**

```python
def stop(self):
    """Stop the monitoring daemon"""
    self.running = False
    self.logger.info("Anti-DDoS Monitor stopping - cleaning up firewall rules")
    
    # CRÍTICO: Limpiar reglas de firewall al detener el servicio
    try:
        self.firewall.cleanup()
        self.logger.info("Firewall rules cleaned up successfully")
    except Exception as e:
        self.logger.error(f"Error cleaning up firewall: {e}")
    
    self.logger.info("Anti-DDoS Monitor stopped")
    sys.exit(0)
```

✅ **Ahora limpia todas las reglas correctamente**

### Solución #2: Cleanup Mejorado de Firewall

**Nuevo código en `firewall.py`:**

```python
def cleanup(self):
    """Remove all firewall rules - SAFE cleanup that preserves Docker/Pterodactyl"""
    
    # Remove jump to our chain from INPUT (todas las instancias)
    while True:
        result = subprocess.run([self.iptables_cmd, '-D', 'INPUT', '-j', self.chain_name], ...)
        if result.returncode != 0:
            break
    
    # Remove jump to our chain from FORWARD
    while True:
        result = subprocess.run([self.iptables_cmd, '-D', 'FORWARD', '-j', self.chain_name], ...)
        if result.returncode != 0:
            break
    
    # Limpiar todas las cadenas ANTIDDOS_PORT_*, ANTIDDOS_MYSQL_*, etc.
    # ... código que busca y elimina todas las cadenas relacionadas
```

✅ **Elimina TODAS las reglas de ANTIDDOS completamente**

### Solución #3: Filtros DoS Optimizados para Gaming

**Nuevo código en `firewall.py`:**

```python
def apply_dos_filters(self):
    """Apply DoS protection filters - SOLO para tráfico NO-Pterodactyl"""
    
    # SYN flood protection - POR IP (no global)
    threshold = self.config.get('dos_filter.syn_flood.threshold', 50)
    self.run_command([
        ..., '-m', 'connlimit', '--connlimit-above', str(threshold), 
        '--connlimit-mask', '32', '-j', 'REJECT'
    ])
    
    # UDP flood protection - MUY PERMISIVO
    threshold = self.config.get('dos_filter.udp_flood.threshold', 100)
    # Límite global: threshold * 10 = 1000/s (muy permisivo)
    self.run_command([
        ..., '-m', 'limit', '--limit', f'{threshold * 10}/s', 
        '--limit-burst', str(threshold * 20), '-j', 'ACCEPT'
    ])
    # ✅ NO DROP - permitir todo UDP que pase el límite global
```

✅ **Cambios**:
- SYN flood ahora usa `connlimit` por IP (más preciso)
- UDP límite aumentado a 1000 PPS (10x más permisivo)
- **Eliminado el DROP de UDP** que estaba bloqueando tráfico legítimo
- ICMP y TCP mantienen protección contra floods

### Solución #4: Configuración Optimizada para Gaming

**Nueva configuración en `config.yaml`:**

```yaml
dos_filter:
  enabled: true
  syn_flood:
    enabled: true
    threshold: 100  # Más permisivo (antes 40)
  udp_flood:
    enabled: true
    threshold: 100  # Base para límite global de 1000/s
  connection_limit:
    enabled: true
    max_connections: 100  # Más permisivo (antes 40)

services:
  enabled: true
  default_threshold_mbps: 15  # Aumentado (antes 8)
  default_threshold_pps: 1000  # Aumentado (antes 500)
  window_seconds: 10  # Ventana más larga (antes 5)
  
  auto_rate_limit:
    enabled: false  # ❌ DESACTIVADO - causaba lag
    
  auto_udp_block:
    enabled: false  # ❌ DESACTIVADO - bloqueaba Minecraft
    
  auto_blacklist:
    enabled: true
    min_connections: 50  # Aumentado (antes 10)
```

✅ **Optimizaciones**:
- Rate limiting y UDP blocking automático DESACTIVADOS
- Thresholds aumentados para evitar false positives
- Solo se banean IPs con 50+ conexiones simultáneas (muy sospechoso)

## 🔧 Cómo Aplicar la Solución

### Paso 1: Limpiar Reglas Residuales

```bash
# Ejecutar script de limpieza
cd /opt/anti-ddos
sudo chmod +x scripts/fix-gaming-disconnects.sh
sudo bash scripts/fix-gaming-disconnects.sh
```

Este script:
1. Detiene servicios ANTIDDOS
2. Elimina TODAS las cadenas y reglas ANTIDDOS
3. Verifica que Docker sigue funcionando
4. Aplica reglas mínimas necesarias

### Paso 2: Actualizar el Código

```bash
cd /opt/anti-ddos
sudo git pull origin main
sudo pip3 install -e . --force-reinstall
```

### Paso 3: Actualizar Configuración

```bash
# Backup de configuración actual
sudo cp /etc/antiddos/config.yaml /etc/antiddos/config.yaml.backup

# Copiar nueva configuración
sudo cp config/config.yaml /etc/antiddos/config.yaml
```

⚠️ **IMPORTANTE**: Verifica que tus IPs whitelisted y configuraciones personalizadas se preserven.

### Paso 4: Probar SIN ANTIDDOS Primero

```bash
# Asegurarse que el servicio está detenido
sudo systemctl stop antiddos-monitor
sudo systemctl status antiddos-monitor

# Verificar que NO hay reglas ANTIDDOS
sudo iptables -L -n | grep ANTIDDOS
# No debería mostrar nada

# Probar conexión de jugadores
# Si funciona, continuar al paso 5
```

### Paso 5: Reiniciar ANTIDDOS con Nueva Configuración

```bash
# Iniciar servicio
sudo systemctl start antiddos-monitor

# Monitorear logs
sudo journalctl -u antiddos-monitor -f
```

### Paso 6: Verificar que Funciona

```bash
# Ver reglas actuales
sudo iptables -L ANTIDDOS -n -v

# Verificar que los filtros UDP son permisivos
# Deberías ver: limit: avg 1000/sec burst 2000

# Probar conectar jugadores
# Deben poder entrar y jugar sin desconexiones
```

## 📊 Comparación Antes/Después

| Métrica | Antes (Defectuoso) | Después (Arreglado) |
|---------|-------------------|---------------------|
| UDP limit global | 80 PPS | 1000 PPS |
| UDP limit por IP | Bloqueado después de 80 PPS | Sin límite por IP |
| SYN flood | Límite global | Límite por IP (100) |
| Max connections | 40 | 100 |
| Auto rate limiting | ✅ Activo (causaba lag) | ❌ Desactivado |
| Auto UDP block | ✅ Activo (bloqueaba gaming) | ❌ Desactivado |
| Cleanup al detener | ❌ No funcionaba | ✅ Funciona |
| Threshold PPS | 500 | 1000 |
| Window seconds | 5 | 10 |

## 🎮 Comportamiento Esperado Ahora

### Tráfico Gaming Normal (10-50 jugadores)

```
Jugador conecta → iptables INPUT
                       ↓
                 1. Loopback? NO
                 2. Established? NO (primera vez)
                 3. Docker interface? NO
                 4. Private network? NO
                 5. ANTIDDOS chain
                       ↓
                 • SYN flood check (100 max per IP) ✅ PASS
                 • UDP flood check (1000/s global) ✅ PASS
                 • Connection limit (100 max TCP) ✅ PASS
                       ↓
                 ✅ ACCEPT
                       ↓
                 Docker NAT → Contenedor → Servidor
```

### Pico de Tráfico (Evento, 100+ jugadores)

```
100 jugadores conectando simultáneamente
                       ↓
              Genera ~500-800 PPS UDP
                       ↓
         UDP check (1000/s global) ✅ PASS
                       ↓
              ✅ TODOS CONECTAN
                       ↓
         Servicio NO detecta "ataque"
         (threshold aumentado a 1000 PPS)
```

### Ataque DDoS Real (5000+ PPS)

```
Ataque DDoS con 5000 PPS
                       ↓
     UDP limit global (1000/s) ❌ EXCEDIDO
                       ↓
         Servicio detecta ataque
                       ↓
    Activa mitigación GLOBAL (strict_limits)
                       ↓
    • Filtrado por país (si configurado)
    • Blacklist automático de IPs atacantes
    • Rate limiting GLOBAL más estricto
                       ↓
         ✅ Ataque mitigado
         ✅ Jugadores legítimos siguen conectados
            (por whitelist o por tráfico normal)
```

## ⚠️ Advertencias

### 1. No Usar Scripts de Desactivación Antiguos

❌ **NO ejecutar**:
```bash
sudo bash scripts/disable-antiddos-temporarily.sh  # OBSOLETO
```

Este script hace `iptables -F INPUT` que es peligroso.

✅ **Usar en su lugar**:
```bash
sudo bash scripts/fix-gaming-disconnects.sh  # SEGURO
```

### 2. Verificar Siempre el Cleanup

Después de detener el servicio:

```bash
# Verificar que no quedan reglas
sudo iptables -L ANTIDDOS -n 2>/dev/null

# Si muestra algo, el cleanup no funcionó
# Ejecutar:
sudo bash scripts/fix-gaming-disconnects.sh
```

### 3. Monitorear Logs Después de Cambios

```bash
# Ver logs en tiempo real
sudo journalctl -u antiddos-monitor -f

# Buscar mensajes de cleanup
sudo journalctl -u antiddos-monitor | grep -i "cleanup"

# Deberías ver:
# "Firewall rules cleaned up successfully"
```

## 🔍 Diagnóstico

### Síntoma: Jugadores siguen desconectándose

**Diagnóstico 1: Verificar si ANTIDDOS está activo**

```bash
# Ver proceso
ps aux | grep antiddos

# Ver reglas
sudo iptables -L ANTIDDOS -n

# Si hay reglas pero el proceso no está corriendo:
# → Problema de cleanup, ejecutar fix-gaming-disconnects.sh
```

**Diagnóstico 2: Verificar límites aplicados**

```bash
# Ver reglas UDP
sudo iptables -L ANTIDDOS -n -v | grep udp

# Deberías ver algo como:
# ... limit: avg 1000/sec burst 2000 ...

# Si ves límites bajos (< 500), la config no se aplicó
```

**Diagnóstico 3: Verificar Docker/Wings**

```bash
# Ver contenedores
docker ps

# Ver logs de Wings
sudo journalctl -u wings -n 50

# Ver reglas NAT
sudo iptables -t nat -L DOCKER -n | grep dpt
```

## 📝 Resumen

### Problema Principal
Las reglas de firewall **no se limpiaban al detener el servicio**, quedando activas y bloqueando jugadores incluso con ANTIDDOS "desactivado".

### Solución Principal
1. Agregar cleanup apropiado en `monitor.stop()`
2. Mejorar método `firewall.cleanup()` para eliminar TODAS las reglas
3. Optimizar filtros DoS para gaming (UDP más permisivo)
4. Desactivar auto rate limiting y UDP blocking que causaban false positives

### Verificación
```bash
# Después de aplicar los cambios:
sudo systemctl stop antiddos-monitor
sudo iptables -L ANTIDDOS -n
# Debería dar error: "No chain/target/match by that name"
# ✅ Esto confirma que el cleanup funciona
```

---

**Última actualización**: 2024-11-21  
**Versión**: 1.0.2  
**Estado**: CRÍTICO - Aplica inmediatamente si tienes gaming servers
