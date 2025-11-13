# Actualización de Seguridad v1.0.1

## 🛡️ Protección de Docker/Pterodactyl Implementada

Esta actualización crítica agrega protecciones para garantizar que el sistema Anti-DDoS **NUNCA** modifique las reglas de firewall de Docker o Pterodactyl Wings.

## ⚠️ Problema Resuelto

**Antes de v1.0.1**: El sistema podía accidentalmente:
- Limpiar la tabla NAT de iptables (rompe Docker)
- Modificar cadenas DOCKER
- Cambiar la política de FORWARD
- Eliminar reglas de la subnet de Pterodactyl

**Después de v1.0.1**: Todas estas operaciones están **BLOQUEADAS** automáticamente.

## 🔒 Protecciones Implementadas

### 1. Cadenas Protegidas

Estas cadenas **NO PUEDEN** ser modificadas:
```
- DOCKER
- DOCKER-ISOLATION-STAGE-1
- DOCKER-ISOLATION-STAGE-2
- DOCKER-USER
```

### 2. Subnet de Pterodactyl Wings Protegida

La subnet `172.18.0.0/16` está explícitamente protegida:
- ✅ TODO el tráfico desde/hacia esta subnet es permitido
- ✅ NO se aplican rate limits
- ✅ NO se bloquean IPs de esta subnet
- ✅ Reglas agregadas al inicio de INPUT (máxima prioridad)

### 3. Operaciones Peligrosas Bloqueadas

El sistema ahora bloquea automáticamente:
```bash
❌ iptables -t nat -F          # Rompe Docker
❌ iptables -t nat -X          # Elimina cadenas NAT
❌ iptables -P FORWARD DROP    # Bloquea tráfico Docker
❌ iptables -F FORWARD         # Limpia reglas de Docker
❌ iptables -F DOCKER          # Modifica cadenas Docker
```

## 📝 Cambios en el Código

### `src/antiddos/firewall.py`

```python
# Nuevas constantes
PROTECTED_CHAINS = ['DOCKER', 'DOCKER-ISOLATION-STAGE-1', ...]
PROTECTED_SUBNETS = ['172.18.0.0/16', ...]

# Nuevos métodos de validación
def _is_protected_chain_modification(self, cmd) -> bool
def _is_dangerous_operation(self, cmd) -> bool

# Método mejorado
def _add_docker_exceptions(self):
    # Ahora incluye protección bidireccional de subnets
    # Agrega reglas a FORWARD para Docker
```

### Scripts Actualizados

**`uninstall.sh`**
- Solo elimina la cadena ANTIDDOS
- Preserva todas las reglas de Docker/Pterodactyl
- Agrega mensaje de confirmación

**`scripts/complete-uninstall.sh`**
- Ya NO limpia todas las reglas de iptables
- Solo elimina cadenas ANTIDDOS
- Preserva NAT, FORWARD y cadenas DOCKER
- Agrega advertencias claras

## 🔍 Verificación

### Comprobar que las protecciones funcionan

```bash
# 1. Ver cadenas protegidas
sudo iptables -L DOCKER -n
sudo iptables -t nat -L DOCKER -n

# 2. Ver subnet de Pterodactyl protegida
sudo iptables -L INPUT -n | grep 172.18.0.0

# 3. Ver logs de operaciones bloqueadas
sudo tail -f /var/log/antiddos/antiddos.log | grep BLOCKED
```

### Ejemplo de log cuando se bloquea una operación

```
[2024-11-12 10:30:45] WARNING - BLOCKED: Attempted to modify protected chain: iptables -F DOCKER
[2024-11-12 10:30:46] WARNING - BLOCKED: Dangerous operation prevented: iptables -t nat -F
[2024-11-12 10:30:47] INFO - Docker exceptions added with full subnet protection
```

## 📚 Nueva Documentación

Se agregó el archivo `docs/FIREWALL_SAFETY.md` con:
- Lista completa de protecciones
- Arquitectura de seguridad
- Mejores prácticas
- Solución de problemas
- Ejemplos de comandos seguros vs peligrosos

## 🚀 Cómo Actualizar

### Opción 1: Git Pull (Recomendado)

```bash
cd /opt/anti-ddos
git pull origin main
sudo systemctl restart antiddos-monitor
```

### Opción 2: Reinstalación

```bash
cd /opt/anti-ddos
sudo bash uninstall.sh
git pull origin main
sudo bash install.sh
```

### Opción 3: Solo Actualizar Código Python

```bash
cd /opt/anti-ddos
git pull origin main
sudo pip3 install -e .
sudo systemctl restart antiddos-monitor
```

## ✅ Verificar Actualización

```bash
# Ver versión
cat /opt/anti-ddos/VERSION
# Debe mostrar: 1.0.1

# Ver que las protecciones están activas
sudo python3 -c "from antiddos.firewall import FirewallManager; print(FirewallManager.PROTECTED_CHAINS)"
# Debe mostrar: ['DOCKER', 'DOCKER-ISOLATION-STAGE-1', ...]

# Ver logs
sudo journalctl -u antiddos-monitor -n 50
```

## 🎯 Beneficios

1. **Seguridad**: Imposible romper Docker/Pterodactyl accidentalmente
2. **Confiabilidad**: Los contenedores siempre funcionarán
3. **Transparencia**: Logs claros de operaciones bloqueadas
4. **Reversibilidad**: Desinstalación segura sin afectar Docker

## 📞 Soporte

Si tienes problemas después de actualizar:

1. Revisa logs: `sudo tail -f /var/log/antiddos/antiddos.log`
2. Ejecuta diagnóstico: `sudo bash scripts/diagnose.sh`
3. Verifica reglas: `sudo iptables -L -n -v`
4. Reinicia servicios: `sudo systemctl restart antiddos-monitor`

## 🔄 Compatibilidad

Esta actualización es **100% compatible** con:
- ✅ Instalaciones existentes de v1.0.0
- ✅ Pterodactyl Wings (todas las versiones)
- ✅ Docker (todas las versiones)
- ✅ Configuraciones personalizadas

**NO** requiere cambios en `config.yaml`.

## 📊 Resumen de Archivos Modificados

```
Modificados:
- src/antiddos/firewall.py          (+120 líneas, protecciones)
- uninstall.sh                      (+5 líneas, advertencias)
- scripts/complete-uninstall.sh     (-30 líneas, seguridad)
- CHANGELOG.md                      (+30 líneas, documentación)
- VERSION                           (1.0.0 → 1.0.1)

Nuevos:
- docs/FIREWALL_SAFETY.md           (Guía completa de seguridad)
- SECURITY_UPDATE.md                (Este archivo)
```

---

**Fecha**: 2024-11-12  
**Versión**: 1.0.1  
**Prioridad**: CRÍTICA (Actualización recomendada)  
**Impacto**: Protección de infraestructura Docker/Pterodactyl
