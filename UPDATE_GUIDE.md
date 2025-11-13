# 🔄 Guía de Actualización a v1.0.1

## 📋 Antes de Actualizar

### Verificar Versión Actual

```bash
cd /opt/anti-ddos
cat VERSION
```

Si muestra `1.0.0` o anterior, necesitas actualizar.

### Verificar Estado Actual

```bash
# Ver servicios
sudo systemctl status antiddos-monitor

# Ver reglas actuales
sudo iptables -L ANTIDDOS -n

# Ver configuración
sudo cat /etc/antiddos/config.yaml
```

## 🚀 Métodos de Actualización

### Método 1: Actualización Completa (Recomendado)

Este método hace backup completo y verifica todo:

```bash
cd /opt/anti-ddos
sudo bash update-to-v1.0.1.sh
```

**Incluye:**
- ✅ Backup automático de configuración
- ✅ Actualización desde GitHub
- ✅ Preservación de whitelist/blacklist
- ✅ Verificación de protecciones
- ✅ Test automático

**Duración**: ~2-3 minutos

---

### Método 2: Actualización Rápida

Para actualización rápida sin verificaciones extensivas:

```bash
cd /opt/anti-ddos
sudo bash quick-update.sh
```

**Incluye:**
- ✅ Backup de configuración
- ✅ Actualización de código
- ✅ Reinicio de servicios

**Duración**: ~30 segundos

---

### Método 3: Actualización Manual

Si prefieres control total:

```bash
# 1. Backup
sudo mkdir -p /tmp/antiddos-backup
sudo cp -r /etc/antiddos/* /tmp/antiddos-backup/

# 2. Detener servicios
sudo systemctl stop antiddos-monitor antiddos-ssh antiddos-xcord

# 3. Actualizar código
cd /opt/anti-ddos
git fetch origin
git reset --hard origin/main

# 4. Actualizar paquete Python
sudo pip3 install -e . --upgrade

# 5. Restaurar configuración
sudo cp /tmp/antiddos-backup/* /etc/antiddos/

# 6. Reiniciar servicios
sudo systemctl daemon-reload
sudo systemctl start antiddos-monitor antiddos-ssh antiddos-xcord
```

---

## ✅ Verificación Post-Actualización

### 1. Verificar Versión

```bash
cat /opt/anti-ddos/VERSION
# Debe mostrar: 1.0.1
```

### 2. Verificar Servicios

```bash
sudo systemctl status antiddos-monitor
sudo systemctl status antiddos-ssh
sudo systemctl status antiddos-xcord
```

Todos deben mostrar: `active (running)`

### 3. Verificar Protecciones Docker

```bash
# Ejecutar test automático
sudo bash /opt/anti-ddos/scripts/test-protections.sh
```

Debe mostrar:
- ✅ Cadena DOCKER intacta
- ✅ Subnet 172.18.0.0/16 protegida
- ✅ Docker activo
- ✅ Wings activo

### 4. Verificar Logs

```bash
# Ver logs en tiempo real
sudo journalctl -u antiddos-monitor -f

# Buscar errores
sudo journalctl -u antiddos-monitor -n 50 | grep -i error

# Ver logs de protecciones
sudo tail -f /var/log/antiddos/antiddos.log
```

### 5. Verificar Reglas de Firewall

```bash
# Ver subnet protegida
sudo iptables -L INPUT -n | grep 172.18.0

# Ver cadenas Docker
sudo iptables -t nat -L DOCKER -n

# Ver cadena ANTIDDOS
sudo iptables -L ANTIDDOS -n
```

---

## 🔍 Solución de Problemas

### Problema: Servicios no inician

```bash
# Ver error específico
sudo journalctl -u antiddos-monitor -n 100 --no-pager

# Reinstalar paquete
cd /opt/anti-ddos
sudo pip3 install -e . --force-reinstall

# Reiniciar
sudo systemctl restart antiddos-monitor
```

### Problema: Configuración perdida

```bash
# Restaurar desde backup
sudo cp /tmp/antiddos-backup-*/* /etc/antiddos/

# O usar configuración de ejemplo
sudo cp /opt/anti-ddos/config/config.yaml /etc/antiddos/

# Reiniciar servicios
sudo systemctl restart antiddos-monitor
```

### Problema: Docker no funciona

```bash
# Verificar que Docker está activo
sudo systemctl status docker

# Reiniciar Docker
sudo systemctl restart docker

# Verificar reglas
sudo iptables -t nat -L DOCKER -n

# Si falta, ejecutar fix
sudo bash /opt/anti-ddos/scripts/fix-pterodactyl-docker.sh
```

### Problema: Wings no funciona

```bash
# Verificar Wings
sudo systemctl status wings

# Ver logs de Wings
sudo journalctl -u wings -n 50

# Reiniciar Wings
sudo systemctl restart wings

# Verificar subnet
sudo iptables -L INPUT -n | grep 172.18.0
```

---

## 📊 Comparación de Versiones

| Característica | v1.0.0 | v1.0.1 |
|----------------|--------|--------|
| Protección Docker | ⚠️ Básica | ✅ Completa |
| Subnet 172.18.0.0/16 | ⚠️ Implícita | ✅ Explícita |
| Bloqueo operaciones peligrosas | ❌ No | ✅ Sí |
| Validación de comandos | ❌ No | ✅ Sí |
| Limpieza segura | ⚠️ Básica | ✅ Completa |
| Documentación seguridad | ❌ No | ✅ Sí |
| Script de verificación | ❌ No | ✅ Sí |

---

## 🎯 Nuevas Características v1.0.1

### 1. Protección de Cadenas Docker

```python
PROTECTED_CHAINS = [
    'DOCKER',
    'DOCKER-ISOLATION-STAGE-1',
    'DOCKER-ISOLATION-STAGE-2',
    'DOCKER-USER'
]
```

### 2. Protección de Subnets

```python
PROTECTED_SUBNETS = [
    '172.16.0.0/12',
    '172.18.0.0/16',  # ← Pterodactyl Wings
    '10.0.0.0/8',
    '192.168.0.0/16',
    '127.0.0.0/8'
]
```

### 3. Validación de Operaciones

Bloquea automáticamente:
- ❌ `iptables -t nat -F`
- ❌ `iptables -F DOCKER`
- ❌ `iptables -P FORWARD DROP`
- ❌ Cualquier modificación a cadenas protegidas

### 4. Nueva Documentación

- `docs/FIREWALL_SAFETY.md` - Guía de seguridad
- `GARANTIAS_DOCKER.md` - Garantías técnicas
- `SECURITY_UPDATE.md` - Detalles de actualización

### 5. Script de Verificación

```bash
sudo bash scripts/test-protections.sh
```

---

## 📞 Soporte

Si tienes problemas durante la actualización:

1. **Ver logs**: `sudo journalctl -u antiddos-monitor -n 100`
2. **Ejecutar diagnóstico**: `sudo bash scripts/diagnose.sh`
3. **Verificar protecciones**: `sudo bash scripts/test-protections.sh`
4. **Restaurar backup**: `sudo cp /tmp/antiddos-backup-*/* /etc/antiddos/`

---

## ⏱️ Tiempo de Inactividad

- **Método 1 (Completo)**: ~2-3 minutos
- **Método 2 (Rápido)**: ~30 segundos
- **Método 3 (Manual)**: ~1-2 minutos

Durante la actualización:
- ✅ Docker sigue funcionando
- ✅ Wings sigue funcionando
- ✅ Contenedores siguen corriendo
- ⚠️ Protección Anti-DDoS temporalmente desactivada

---

## 🔄 Rollback (Volver a v1.0.0)

Si necesitas volver a la versión anterior:

```bash
cd /opt/anti-ddos
sudo systemctl stop antiddos-monitor antiddos-ssh antiddos-xcord
git checkout v1.0.0
sudo pip3 install -e . --force-reinstall
sudo systemctl start antiddos-monitor antiddos-ssh antiddos-xcord
```

---

**Recomendación**: Usa el **Método 1 (Actualización Completa)** para máxima seguridad y verificación.
