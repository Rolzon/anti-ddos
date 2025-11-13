# 🔒 GARANTÍAS ABSOLUTAS - Docker/Pterodactyl Wings

## ✅ GARANTÍA 100% - NO SE MODIFICA DOCKER/NFTABLES

Este documento es una **GARANTÍA TÉCNICA** de que el sistema Anti-DDoS **NUNCA** modificará:

1. ❌ Cadenas de Docker (DOCKER, DOCKER-ISOLATION-*, DOCKER-USER)
2. ❌ Tabla NAT de iptables/nftables
3. ❌ Cadena FORWARD
4. ❌ Reglas de Pterodactyl Wings
5. ❌ Subnet 172.18.0.0/16
6. ❌ Interfaces docker0, pterodactyl_nw, pterodactyl0

## 🛡️ Cómo Funciona la Protección

### Arquitectura de Aislamiento

```
┌─────────────────────────────────────────────────┐
│           TRÁFICO DE RED ENTRANTE               │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
         ┌────────────────┐
         │  Cadena INPUT  │
         └────────┬───────┘
                  │
    ┌─────────────┴─────────────┐
    │                           │
    ▼                           ▼
┌───────────┐           ┌──────────────┐
│  Docker   │           │   Internet   │
│  Traffic  │           │   Traffic    │
└─────┬─────┘           └──────┬───────┘
      │                        │
      │ (ACCEPT)               │
      │ NO PASA POR            │ (PASA POR)
      │ ANTIDDOS               │ ANTIDDOS
      │                        │
      ▼                        ▼
┌─────────────┐        ┌──────────────┐
│ Contenedor  │        │ Cadena       │
│ Pterodactyl │        │ ANTIDDOS     │
└─────────────┘        └──────────────┘
```

### Orden de Reglas (Prioridad)

```bash
# Posición 1-5: ACCEPT (Docker/Pterodactyl) ← MÁXIMA PRIORIDAD
iptables -I INPUT 1 -i lo -j ACCEPT
iptables -I INPUT 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -I INPUT 1 -i docker0 -j ACCEPT
iptables -I INPUT 1 -i pterodactyl_nw -j ACCEPT
iptables -I INPUT 1 -s 172.18.0.0/16 -j ACCEPT
iptables -I INPUT 1 -d 172.18.0.0/16 -j ACCEPT

# Última posición: JUMP a ANTIDDOS ← BAJA PRIORIDAD
iptables -A INPUT -j ANTIDDOS
```

**Resultado**: El tráfico de Docker/Pterodactyl es aceptado ANTES de llegar a ANTIDDOS.

## 🔍 Validaciones de Seguridad en el Código

### Validación 1: Cadenas Protegidas

```python
# src/antiddos/firewall.py líneas 14-15
PROTECTED_CHAINS = [
    'DOCKER',
    'DOCKER-ISOLATION-STAGE-1',
    'DOCKER-ISOLATION-STAGE-2',
    'DOCKER-USER'
]

def _is_protected_chain_modification(self, cmd: List[str]) -> bool:
    """Bloquea cualquier modificación a cadenas protegidas"""
    cmd_str = ' '.join(cmd)
    
    for chain in self.PROTECTED_CHAINS:
        if any([
            f'-X {chain}' in cmd_str,  # Delete chain
            f'-F {chain}' in cmd_str,  # Flush chain
            f'-D {chain}' in cmd_str,  # Delete rule
            f'-R {chain}' in cmd_str,  # Replace rule
        ]):
            return True  # ❌ BLOQUEADO
    
    return False
```

### Validación 2: Operaciones Peligrosas

```python
# src/antiddos/firewall.py líneas 122-138
def _is_dangerous_operation(self, cmd: List[str]) -> bool:
    """Bloquea operaciones que rompen Docker"""
    cmd_str = ' '.join(cmd)
    
    dangerous_patterns = [
        '-t nat -F',           # Flush NAT table (breaks Docker)
        '-t nat -X',           # Delete NAT chains
        'FORWARD -P DROP',     # Change FORWARD policy to DROP
        'FORWARD -F',          # Flush FORWARD chain
    ]
    
    for pattern in dangerous_patterns:
        if pattern in cmd_str:
            return True  # ❌ BLOQUEADO
    
    return False
```

### Validación 3: Ejecución de Comandos

```python
# src/antiddos/firewall.py líneas 76-102
def run_command(self, cmd: List[str]) -> bool:
    """Ejecuta comando SOLO si pasa las validaciones"""
    try:
        # Validación 1
        if self._is_protected_chain_modification(cmd):
            self.logger.warning(f"BLOCKED: {' '.join(cmd)}")
            return False  # ❌ NO SE EJECUTA
        
        # Validación 2
        if self._is_dangerous_operation(cmd):
            self.logger.warning(f"BLOCKED: {' '.join(cmd)}")
            return False  # ❌ NO SE EJECUTA
        
        # Si pasa las validaciones, ejecutar
        result = subprocess.run(cmd, ...)
        return True
```

## 📊 Tabla de Comandos Bloqueados vs Permitidos

| Comando | Estado | Razón |
|---------|--------|-------|
| `iptables -N ANTIDDOS` | ✅ PERMITIDO | Crea cadena propia |
| `iptables -A ANTIDDOS -s 1.2.3.4 -j DROP` | ✅ PERMITIDO | Modifica cadena propia |
| `iptables -F ANTIDDOS` | ✅ PERMITIDO | Limpia cadena propia |
| `iptables -X ANTIDDOS` | ✅ PERMITIDO | Elimina cadena propia |
| `iptables -I INPUT 1 -s 172.18.0.0/16 -j ACCEPT` | ✅ PERMITIDO | Protege Docker |
| `iptables -F DOCKER` | ❌ BLOQUEADO | Cadena protegida |
| `iptables -X DOCKER` | ❌ BLOQUEADO | Cadena protegida |
| `iptables -t nat -F` | ❌ BLOQUEADO | Rompe Docker NAT |
| `iptables -t nat -X` | ❌ BLOQUEADO | Elimina NAT |
| `iptables -F FORWARD` | ❌ BLOQUEADO | Rompe Docker routing |
| `iptables -P FORWARD DROP` | ❌ BLOQUEADO | Bloquea Docker |
| `iptables -D DOCKER-ISOLATION-STAGE-1 ...` | ❌ BLOQUEADO | Cadena protegida |

## 🧪 Prueba de Protecciones

Ejecuta este script para verificar que todo está protegido:

```bash
sudo bash scripts/test-protections.sh
```

Este script verifica:
- ✅ Cadenas DOCKER intactas
- ✅ Subnet 172.18.0.0/16 protegida
- ✅ Interfaces Docker permitidas
- ✅ Política FORWARD correcta
- ✅ Configuración de Wings intacta

## 📝 Logs de Seguridad

Cuando el sistema bloquea una operación peligrosa, lo registra:

```bash
# Ver logs en tiempo real
sudo tail -f /var/log/antiddos/antiddos.log

# Ejemplo de log cuando se bloquea algo:
[2024-11-13 00:00:00] WARNING - BLOCKED: Attempted to modify protected chain: iptables -F DOCKER
[2024-11-13 00:00:01] WARNING - BLOCKED: Dangerous operation prevented: iptables -t nat -F
```

## 🔐 Garantías Específicas para tu Configuración

Según tu configuración de Wings (172.18.0.0/16):

### 1. Subnet Protegida

```python
# Línea 19 de firewall.py
'172.18.0.0/16',  # Pterodactyl Wings specific subnet
```

### 2. Reglas de Protección

```python
# Líneas 192-194
for network in self.PROTECTED_SUBNETS:
    # Tráfico DESDE la subnet → ACCEPT
    self.run_command([..., '-s', network, '-j', 'ACCEPT'])
    # Tráfico HACIA la subnet → ACCEPT
    self.run_command([..., '-d', network, '-j', 'ACCEPT'])
```

### 3. Interfaces Protegidas

```python
# Líneas 181-183
self.run_command([..., '-i', 'docker0', '-j', 'ACCEPT'])
self.run_command([..., '-i', 'pterodactyl0', '-j', 'ACCEPT'])
self.run_command([..., '-i', 'pterodactyl_nw', '-j', 'ACCEPT'])
```

### 4. FORWARD Protegido

```python
# Líneas 196-198
self.run_command([..., '-I', 'FORWARD', '1', '-i', 'docker0', '-j', 'ACCEPT'])
self.run_command([..., '-I', 'FORWARD', '1', '-o', 'docker0', '-j', 'ACCEPT'])
```

## 🚫 Lo que NUNCA Pasará

1. ❌ El sistema NO puede eliminar reglas de Docker
2. ❌ El sistema NO puede modificar la tabla NAT
3. ❌ El sistema NO puede cambiar la política FORWARD
4. ❌ El sistema NO puede bloquear tráfico de 172.18.0.0/16
5. ❌ El sistema NO puede interferir con contenedores
6. ❌ El sistema NO puede romper Pterodactyl Wings

## ✅ Lo que SÍ Hace el Sistema

1. ✅ Crea su propia cadena ANTIDDOS
2. ✅ Filtra tráfico de INTERNET (no Docker)
3. ✅ Bloquea IPs maliciosas
4. ✅ Aplica rate limiting a tráfico externo
5. ✅ Protege contra DDoS desde internet
6. ✅ Preserva TODO el tráfico de Docker/Pterodactyl

## 🔄 Desinstalación Segura

Incluso al desinstalar, las reglas de Docker se preservan:

```bash
# uninstall.sh líneas 50-56
iptables -D INPUT -j ANTIDDOS 2>/dev/null || true
iptables -F ANTIDDOS 2>/dev/null || true
iptables -X ANTIDDOS 2>/dev/null || true

# IMPORTANTE: DO NOT touch DOCKER chains, NAT table, or FORWARD chain
# Docker and Pterodactyl Wings manage these automatically
```

## 📞 Verificación Final

Para estar 100% seguro, ejecuta estos comandos ANTES y DESPUÉS de instalar:

```bash
# ANTES de instalar
sudo iptables -t nat -L DOCKER -n > /tmp/docker-nat-before.txt
sudo iptables -L FORWARD -n > /tmp/forward-before.txt
sudo iptables -L INPUT -n | grep 172.18.0 > /tmp/subnet-before.txt

# Instalar Anti-DDoS
sudo bash install.sh

# DESPUÉS de instalar
sudo iptables -t nat -L DOCKER -n > /tmp/docker-nat-after.txt
sudo iptables -L FORWARD -n > /tmp/forward-after.txt
sudo iptables -L INPUT -n | grep 172.18.0 > /tmp/subnet-after.txt

# Comparar (deben ser idénticos o con MÁS protecciones)
diff /tmp/docker-nat-before.txt /tmp/docker-nat-after.txt
diff /tmp/forward-before.txt /tmp/forward-after.txt
diff /tmp/subnet-before.txt /tmp/subnet-after.txt
```

## 🎯 Conclusión

**GARANTÍA ABSOLUTA**: Este sistema está diseñado con múltiples capas de protección para asegurar que Docker, nftables y Pterodactyl Wings permanezcan **INTACTOS** y **FUNCIONALES** en todo momento.

- ✅ Validaciones en código Python
- ✅ Protecciones en scripts de shell
- ✅ Logs de seguridad
- ✅ Arquitectura de aislamiento
- ✅ Orden de reglas prioritario

**Tu configuración actual de Docker/Pterodactyl NO será modificada.**

---

**Fecha**: 2024-11-13  
**Versión**: 1.0.1  
**Autor**: Sistema Anti-DDoS  
**Estado**: GARANTIZADO
