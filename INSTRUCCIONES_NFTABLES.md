# 🚨 INSTRUCCIONES PARA TU SERVIDOR (nftables)

Tu servidor usa **nftables backend**. Aquí están los pasos exactos para solucionar el problema.

## ✅ PASO 1: Limpieza Manual Inmediata

```bash
cd /opt/anti-ddos

# Dar permisos a los scripts
sudo chmod +x scripts/manual-cleanup-nftables.sh
sudo chmod +x scripts/verify-cleanup.sh

# Ejecutar limpieza manual
sudo bash scripts/manual-cleanup-nftables.sh
```

**Resultado esperado:**
```
✓ ÉXITO: Sistema limpio - no hay cadenas ANTIDDOS
```

## ✅ PASO 2: Verificar que Jugadores Pueden Conectar

**IMPORTANTE:** Antes de actualizar el código, verifica que los jugadores pueden conectar ahora:

```bash
# Ver puertos escuchando
sudo ss -tulnp | grep -E "25565|19132"

# Probar conexión local
nc -zv 127.0.0.1 25565

# Pedir a jugadores que intenten conectar
# ¿Pueden jugar sin desconexiones?
```

✅ **Si funciona:** El problema ERA las reglas ANTIDDOS → Continúa al PASO 3  
❌ **Si NO funciona:** El problema NO es el firewall → Ver sección "Otros Problemas" al final

## ✅ PASO 3: Copiar Archivos Actualizados

Necesitas copiar los archivos desde tu máquina Windows al servidor:

### Archivos a copiar:

```
De Windows → Servidor:

src/antiddos/monitor.py          → /opt/anti-ddos/src/antiddos/monitor.py
src/antiddos/firewall.py         → /opt/anti-ddos/src/antiddos/firewall.py
config/config.yaml               → /tmp/config-new.yaml (temporal)
scripts/manual-cleanup-nftables.sh → /opt/anti-ddos/scripts/
scripts/verify-cleanup.sh        → /opt/anti-ddos/scripts/
scripts/fix-gaming-disconnects.sh → /opt/anti-ddos/scripts/
```

### Opción A: Usar SCP (desde Windows)

```powershell
# En PowerShell (Windows)
scp C:\Users\crist\OneDrive\Documentos\Anti-ddos\anti-ddos\src\antiddos\monitor.py root@TU_IP:/opt/anti-ddos/src/antiddos/
scp C:\Users\crist\OneDrive\Documentos\Anti-ddos\anti-ddos\src\antiddos\firewall.py root@TU_IP:/opt/anti-ddos/src/antiddos/
scp C:\Users\crist\OneDrive\Documentos\Anti-ddos\anti-ddos\config\config.yaml root@TU_IP:/tmp/config-new.yaml
scp C:\Users\crist\OneDrive\Documentos\Anti-ddos\anti-ddos\scripts\*.sh root@TU_IP:/opt/anti-ddos/scripts/
```

### Opción B: Usar Git

Si tienes el proyecto en Git:

```bash
# En el servidor
cd /opt/anti-ddos
git pull origin main
```

### Opción C: Copiar manualmente

Abre los archivos en Windows, copia el contenido, y pégalo en el servidor con nano/vim.

## ✅ PASO 4: Actualizar Configuración

```bash
# Hacer backup de la config actual
sudo cp /etc/antiddos/config.yaml /etc/antiddos/config.yaml.backup

# Comparar configs
diff /etc/antiddos/config.yaml /tmp/config-new.yaml

# Actualizar (cuidado con tus IPs whitelist)
sudo cp /tmp/config-new.yaml /etc/antiddos/config.yaml

# IMPORTANTE: Restaurar tus IPs en whitelist
sudo nano /etc/antiddos/config.yaml
# Buscar sección 'whitelist:' y agregar tus IPs
```

## ✅ PASO 5: Reinstalar el Código

```bash
cd /opt/anti-ddos

# Reinstalar
sudo pip3 install -e . --force-reinstall

# Verificar que se instaló
python3 -c "from antiddos import monitor, firewall; print('OK')"
```

## ✅ PASO 6: Probar el Cleanup Mejorado

```bash
# Iniciar servicio
sudo systemctl start antiddos-monitor

# Ver que inició correctamente
sudo journalctl -u antiddos-monitor -n 30

# Buscar línea importante:
# "Using iptables binary: iptables-nft"

# Esperar 5 segundos
sleep 5

# Detener servicio
sudo systemctl stop antiddos-monitor

# Verificar cleanup (DEBE FUNCIONAR AHORA)
sudo bash scripts/verify-cleanup.sh
```

**Resultado esperado:**
```
✓ PASS: Cadena ANTIDDOS no existe (limpiado correctamente)
```

## ✅ PASO 7: Iniciar Servicio y Monitorear

```bash
# Iniciar con nueva configuración
sudo systemctl start antiddos-monitor

# Monitorear logs en tiempo real
sudo journalctl -u antiddos-monitor -f

# Deberías ver:
# - "Anti-DDoS Monitor starting"
# - "Using iptables binary: iptables-nft"
# - "Applying DoS filters (Pterodactyl traffic bypassed)"
# - "UDP flood protection: global limit 1000/s (permisivo para gaming)"
```

## ✅ PASO 8: Verificar Protección Balanceada

### Comando útil para monitorear

```bash
# Terminal 1: Ver logs
sudo journalctl -u antiddos-monitor -f | grep -E "attack|mitigation|legitimate"

# Terminal 2: Ver reglas actuales
watch -n 5 'sudo nft list table ip filter | grep -A 5 ANTIDDOS'
```

### Probar con jugadores

1. **10-20 jugadores conectados:**
   - Log debe mostrar: "Legitimate pattern" o "High traffic but legitimate"
   - NO debe haber mitigación
   - Jugadores juegan normal

2. **50+ jugadores o pico de tráfico:**
   - Si es tráfico legítimo, no debe aplicar mitigación
   - Log: "Tráfico alto pero patrón legítimo"

3. **Durante ataque DDoS real:**
   - Log: "Attack pattern detected"
   - Log: "Bloqueadas X IPs atacantes"
   - Log: "Mitigation applied: Rate limit..."

## 📊 Comandos de Verificación Útiles

### Ver estado del servicio
```bash
sudo systemctl status antiddos-monitor
```

### Ver reglas de firewall (nftables)
```bash
# Todas las reglas
sudo nft list ruleset

# Solo tabla filter
sudo nft list table ip filter

# Buscar ANTIDDOS
sudo nft list table ip filter | grep -A 20 ANTIDDOS
```

### Ver reglas con iptables-nft
```bash
# Listar todas
sudo iptables-nft -L -n -v

# Solo ANTIDDOS
sudo iptables-nft -L ANTIDDOS -n -v

# Formato de script
sudo iptables-nft -S
```

### Ver estadísticas de tráfico
```bash
# Tráfico por servicio
cat /var/run/antiddos/service_stats.json | jq

# PPS actual
sudo iftop -i dr0

# Conexiones por IP
sudo ss -tn | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -20
```

## 🐛 Otros Problemas (Si jugadores NO pueden conectar)

### 1. Verificar Wings
```bash
sudo systemctl status wings
sudo journalctl -u wings -n 50
```

### 2. Verificar Docker
```bash
docker ps
sudo systemctl status docker
```

### 3. Verificar NAT
```bash
# Reglas NAT de Docker
sudo iptables-nft -t nat -L DOCKER -n -v

# Debe mostrar reglas DNAT para puertos gaming
```

### 4. Verificar puertos escuchan
```bash
sudo ss -tulnp | grep -E "25565|19132|19133"
```

### 5. Verificar desde el servidor mismo
```bash
# Java Edition
nc -zv 127.0.0.1 25565

# Bedrock Edition  
nc -zuv 127.0.0.1 19132
```

### 6. Revisar firewall externo
```bash
# UFW
sudo ufw status

# Firewalld
sudo firewall-cmd --list-all
```

## 📝 Resumen de Comandos Rápidos

```bash
# Limpieza manual
sudo bash /opt/anti-ddos/scripts/manual-cleanup-nftables.sh

# Verificar limpieza
sudo bash /opt/anti-ddos/scripts/verify-cleanup.sh

# Ver logs en tiempo real
sudo journalctl -u antiddos-monitor -f

# Ver reglas actuales
sudo nft list table ip filter | grep -A 10 ANTIDDOS

# Reiniciar todo
sudo systemctl restart antiddos-monitor

# Ver si funciona cleanup
sudo systemctl stop antiddos-monitor && sleep 2 && sudo bash scripts/verify-cleanup.sh
```

## ✅ Checklist Final

- [ ] Ejecutado `manual-cleanup-nftables.sh` ✓
- [ ] Jugadores pueden conectar sin ANTIDDOS ✓
- [ ] Archivos actualizados copiados al servidor ✓
- [ ] Código reinstalado con pip3 ✓
- [ ] Config actualizada (preservando whitelist) ✓
- [ ] Servicio reiniciado ✓
- [ ] Cleanup funciona al detener servicio ✓
- [ ] Logs muestran "Using iptables-nft" ✓
- [ ] Jugadores pueden jugar sin desconexiones ✓
- [ ] Sistema detecta ataques DDoS correctamente ✓

---

**¿Algún problema?** Revisa:
- `docs/NFTABLES_CLEANUP_FIX.md` - Fix específico para nftables
- `docs/GAMING_DISCONNECTS_FIX.md` - Problema original detallado
- `docs/BALANCED_PROTECTION.md` - Estrategia de protección completa
- `PASOS_RAPIDOS_SOLUCION.md` - Guía general

---

**Última actualización**: 2024-11-21  
**Para**: dragon01-ProLiant-DL380-Gen10  
**Sistema**: Ubuntu con nftables backend
