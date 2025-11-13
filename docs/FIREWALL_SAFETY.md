# Seguridad del Firewall - Protección de Docker/Pterodactyl

## ⚠️ ADVERTENCIAS CRÍTICAS

Este sistema Anti-DDoS está diseñado para **NUNCA** modificar las reglas críticas de Docker y Pterodactyl Wings. Las siguientes protecciones están implementadas:

## Protecciones Implementadas

### 1. Cadenas Protegidas

Las siguientes cadenas de iptables **NUNCA** serán modificadas, eliminadas o limpiadas:

- `DOCKER`
- `DOCKER-ISOLATION-STAGE-1`
- `DOCKER-ISOLATION-STAGE-2`
- `DOCKER-USER`

Cualquier intento de modificar estas cadenas será **BLOQUEADO** automáticamente por el sistema.

### 2. Subnets Protegidas

Las siguientes subnets están explícitamente protegidas y siempre permitidas:

- `172.16.0.0/12` - Rango por defecto de Docker
- `172.18.0.0/16` - **Subnet específica de Pterodactyl Wings**
- `10.0.0.0/8` - Red privada
- `192.168.0.0/16` - Red privada
- `127.0.0.0/8` - Loopback

### 3. Operaciones Bloqueadas

El sistema bloqueará automáticamente las siguientes operaciones peligrosas:

```bash
# ❌ BLOQUEADO - Limpiar tabla NAT (rompe Docker)
iptables -t nat -F

# ❌ BLOQUEADO - Eliminar cadenas NAT
iptables -t nat -X

# ❌ BLOQUEADO - Cambiar política FORWARD a DROP
iptables -P FORWARD DROP

# ❌ BLOQUEADO - Limpiar cadena FORWARD
iptables -F FORWARD

# ❌ BLOQUEADO - Modificar cadenas DOCKER
iptables -F DOCKER
iptables -X DOCKER
```

### 4. Operaciones Permitidas (Seguras)

El sistema solo modifica su propia cadena `ANTIDDOS`:

```bash
# ✅ PERMITIDO - Crear cadena ANTIDDOS
iptables -N ANTIDDOS

# ✅ PERMITIDO - Agregar reglas a ANTIDDOS
iptables -A ANTIDDOS -s 1.2.3.4 -j DROP

# ✅ PERMITIDO - Limpiar cadena ANTIDDOS
iptables -F ANTIDDOS

# ✅ PERMITIDO - Eliminar cadena ANTIDDOS
iptables -X ANTIDDOS
```

## Arquitectura de Seguridad

### Orden de Reglas en INPUT

```
1. ACCEPT - Loopback (127.0.0.0/8)
2. ACCEPT - Docker interfaces (docker0, pterodactyl0, pterodactyl_nw)
3. ACCEPT - Conexiones establecidas (ESTABLISHED, RELATED)
4. ACCEPT - Subnets protegidas (172.18.0.0/16, etc.)
5. JUMP - Cadena ANTIDDOS (filtros Anti-DDoS)
```

**Importante**: Las reglas de Docker/Pterodactyl están **ANTES** de la cadena ANTIDDOS, por lo que el tráfico de contenedores **NUNCA** pasa por los filtros Anti-DDoS.

### Cadena FORWARD

La cadena FORWARD es crítica para Docker. El sistema:

- ✅ Permite tráfico de/hacia docker0
- ✅ NO modifica las reglas de Docker en FORWARD
- ✅ NO cambia la política de FORWARD

## Validaciones de Seguridad

### En el Código Python (`firewall.py`)

```python
# Validación 1: Cadenas protegidas
PROTECTED_CHAINS = ['DOCKER', 'DOCKER-ISOLATION-STAGE-1', ...]

# Validación 2: Operaciones peligrosas
def _is_dangerous_operation(self, cmd):
    dangerous_patterns = ['-t nat -F', 'FORWARD -P DROP', ...]
    
# Validación 3: Subnets protegidas
PROTECTED_SUBNETS = ['172.18.0.0/16', ...]
```

### En Scripts de Shell

Todos los scripts han sido modificados para:

1. **NO** limpiar cadenas DOCKER
2. **NO** tocar la tabla NAT
3. **NO** modificar la cadena FORWARD
4. **SOLO** limpiar la cadena ANTIDDOS

## Subnet de Pterodactyl Wings

### Configuración Típica

Según tu configuración de Wings (`/etc/pterodactyl/config.yml`):

```yaml
docker:
  network:
    interface: 172.18.0.1
    dns: []
    name: pterodactyl_nw
    ispn: false
    driver: bridge
    network_mode: pterodactyl_nw
    is_internal: false
    enable_icc: true
    network_mtu: 1500
    interfaces:
      v4:
        subnet: 172.18.0.0/16
        gateway: 172.18.0.1
```

### Protección Implementada

El sistema Anti-DDoS:

1. ✅ Permite TODO el tráfico desde/hacia 172.18.0.0/16
2. ✅ Permite la interfaz `pterodactyl_nw`
3. ✅ NO aplica rate limiting a esta subnet
4. ✅ NO bloquea IPs de esta subnet

## Scripts Seguros

### `uninstall.sh`

```bash
# Solo limpia la cadena ANTIDDOS
iptables -D INPUT -j ANTIDDOS
iptables -F ANTIDDOS
iptables -X ANTIDDOS

# ✅ NO toca Docker/Pterodactyl
```

### `complete-uninstall.sh`

```bash
# Limpia SOLO ANTIDDOS
# Preserva todas las reglas de Docker/Pterodactyl
# NO limpia NAT, FORWARD, ni cadenas DOCKER
```

### `fix-pterodactyl-docker.sh`

```bash
# Agrega excepciones para Docker/Pterodactyl
# NO elimina reglas existentes
# Solo agrega reglas de ACCEPT
```

## Verificación

### Comprobar Protecciones

```bash
# Ver cadenas protegidas
sudo iptables -L DOCKER -n
sudo iptables -t nat -L DOCKER -n

# Ver subnet protegida
sudo iptables -L INPUT -n | grep 172.18.0.0

# Ver cadena ANTIDDOS (solo esta es modificada)
sudo iptables -L ANTIDDOS -n
```

### Logs de Seguridad

El sistema registra en `/var/log/antiddos/antiddos.log`:

```
[WARNING] BLOCKED: Attempted to modify protected chain: iptables -F DOCKER
[WARNING] BLOCKED: Dangerous operation prevented: iptables -t nat -F
[INFO] Docker exceptions added with full subnet protection
```

## Mejores Prácticas

### ✅ Hacer

1. Usar los scripts proporcionados
2. Revisar logs antes de hacer cambios manuales
3. Probar en un servidor de desarrollo primero
4. Mantener backups de configuración de Wings

### ❌ NO Hacer

1. NO ejecutar `iptables -F` sin especificar cadena
2. NO limpiar la tabla NAT (`iptables -t nat -F`)
3. NO cambiar la política FORWARD a DROP
4. NO modificar cadenas DOCKER manualmente
5. NO eliminar reglas de subnets protegidas

## Solución de Problemas

### Si Docker/Pterodactyl no funciona

```bash
# 1. Verificar que las reglas de Docker existen
sudo iptables -t nat -L DOCKER -n

# 2. Si no existen, reiniciar Docker
sudo systemctl restart docker

# 3. Verificar subnet protegida
sudo iptables -L INPUT -n | grep 172.18.0

# 4. Si falta, ejecutar fix
sudo bash scripts/fix-pterodactyl-docker.sh
```

### Si Anti-DDoS bloquea algo que no debería

```bash
# Ver qué está bloqueando
sudo tail -f /var/log/antiddos/antiddos.log

# Agregar IP a whitelist
sudo antiddos-cli whitelist add <IP>

# O agregar subnet completa
sudo iptables -I ANTIDDOS 1 -s <SUBNET> -j ACCEPT
```

## Contacto y Soporte

Si encuentras algún problema con las protecciones de firewall:

1. Revisa los logs: `/var/log/antiddos/antiddos.log`
2. Verifica las reglas: `sudo iptables -L -n -v`
3. Ejecuta diagnóstico: `sudo bash scripts/diagnose.sh`

## Changelog de Seguridad

### v1.0.1 (Actual)

- ✅ Agregadas protecciones para cadenas DOCKER
- ✅ Subnet 172.18.0.0/16 explícitamente protegida
- ✅ Validaciones de operaciones peligrosas
- ✅ Scripts actualizados para preservar Docker/Pterodactyl
- ✅ Logs de seguridad mejorados

---

**IMPORTANTE**: Estas protecciones garantizan que el sistema Anti-DDoS **NUNCA** interferirá con Docker o Pterodactyl Wings. Todas las modificaciones de firewall son seguras y reversibles.
