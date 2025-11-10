# Compatibilidad con Docker y Pterodactyl

## 🎯 Problema Resuelto

El sistema Anti-DDoS ahora es **100% compatible** con Docker y Pterodactyl. Los puertos de los servidores de juegos se abren automáticamente sin interferencia del firewall.

## 🔧 Cómo Funciona

### Backend de iptables

El sistema usa `iptables-nft` en lugar de `iptables-legacy`:

- **iptables-nft**: Compatible con Docker, usa el backend `nf_tables` moderno
- **iptables-legacy**: Incompatible, usa el backend antiguo que bloquea Docker

### Orden de Reglas

Las reglas se aplican en este orden:

```
1. Loopback (127.0.0.1)           ← Siempre permitido
2. Conexiones establecidas        ← Docker NAT funciona aquí
3. Interfaces Docker              ← docker0, pterodactyl0, etc.
4. Redes privadas                 ← 172.x.x.x, 10.x.x.x, 192.168.x.x
5. MySQL desde IP específica      ← 190.57.138.18:3306
6. Cadena ANTIDDOS                ← Protección DDoS (al final)
```

**Resultado**: Docker puede abrir puertos dinámicamente sin que ANTIDDOS los bloquee.

## 📦 Configuración Automática

### Script de Compatibilidad

```bash
sudo ./scripts/setup-nft-compatibility.sh
```

Este script:
1. Configura `update-alternatives` para usar `iptables-nft`
2. Limpia completamente `iptables-legacy`
3. Configura Docker para usar iptables
4. Reinicia servicios
5. Verifica la configuración

### Detección Automática

El código Python detecta automáticamente el backend correcto:

```python
def _detect_iptables(self) -> str:
    """Detect which iptables binary to use - prefer nft for Docker compatibility"""
    # Try iptables-nft first (required for Docker/Pterodactyl)
    try:
        result = subprocess.run(['iptables-nft', '-L', '-n'], ...)
        if result.returncode == 0:
            return 'iptables-nft'
    except:
        pass
    
    # Try regular iptables (usually points to nft on modern systems)
    ...
```

## 🛡️ Excepciones de Docker

El sistema agrega automáticamente excepciones para Docker:

```python
def _add_docker_exceptions(self):
    """Add exceptions for Docker/Pterodactyl - these bypass ANTIDDOS"""
    
    # Allow all Docker traffic
    self.run_command([self.iptables_cmd, '-I', 'INPUT', '1', '-i', 'docker0', '-j', 'ACCEPT'])
    self.run_command([self.iptables_cmd, '-I', 'INPUT', '1', '-i', 'pterodactyl0', '-j', 'ACCEPT'])
    
    # Allow established connections (critical for Docker NAT)
    self.run_command([self.iptables_cmd, '-I', 'INPUT', '1', '-m', 'conntrack', 
                     '--ctstate', 'ESTABLISHED,RELATED', '-j', 'ACCEPT'])
    
    # Allow Docker networks
    docker_networks = ['172.16.0.0/12', '10.0.0.0/8', '192.168.0.0/16']
    for network in docker_networks:
        self.run_command([self.iptables_cmd, '-I', 'INPUT', '1', '-s', network, '-j', 'ACCEPT'])
```

## 🔍 Verificación

### Comprobar Backend

```bash
# Ver versión de iptables
iptables --version

# Debe mostrar: iptables v1.8.x (nf_tables)
```

### Comprobar Alternativas

```bash
update-alternatives --display iptables

# Debe mostrar: /usr/sbin/iptables-nft
```

### Comprobar Reglas de Docker

```bash
# Ver cadena DOCKER en NAT
iptables -t nat -L DOCKER -n

# Debe mostrar reglas DNAT para cada puerto de Pterodactyl
```

### Comprobar Orden de Reglas

```bash
# Ver primeras reglas de INPUT
iptables -L INPUT -n --line-numbers | head -20

# Debe mostrar:
# 1. ACCEPT loopback
# 2. ACCEPT established,related
# 3. ACCEPT docker0
# ...
# N. ANTIDDOS (al final)
```

## ⚠️ Problemas Comunes

### Problema: Puertos cerrados después de instalar

**Causa**: `iptables-legacy` está activo junto con `iptables-nft`

**Solución**:
```bash
# Limpiar iptables-legacy
sudo iptables-legacy -F
sudo iptables-legacy -X
sudo iptables-legacy -P INPUT ACCEPT
sudo iptables-legacy -P FORWARD ACCEPT
sudo iptables-legacy -P OUTPUT ACCEPT

# Guardar
sudo netfilter-persistent save
```

### Problema: Docker no crea reglas NAT

**Causa**: Docker no está configurado para usar iptables

**Solución**:
```bash
# Editar configuración de Docker
sudo nano /etc/docker/daemon.json

# Agregar:
{
  "iptables": true
}

# Reiniciar
sudo systemctl restart docker
```

### Problema: Wings no puede iniciar contenedores

**Causa**: Interfaz de Wings configurada incorrectamente

**Solución**:
```bash
# Editar configuración de Wings
sudo nano /etc/pterodactyl/config.yml

# Cambiar:
docker:
  network:
    interface: 0.0.0.0  # NO 172.18.0.1

# Reiniciar
sudo systemctl restart wings
```

## 📊 Flujo de Tráfico

```
Jugador → Internet → Servidor (190.57.138.18:19771)
                           ↓
                    iptables INPUT
                           ↓
                    1. Loopback? NO
                    2. Established? NO (primera conexión)
                    3. Docker interface? NO
                    4. Private network? NO
                    5. MySQL exception? NO
                    6. ANTIDDOS chain
                           ↓
                    Docker NAT (DNAT)
                           ↓
                    Contenedor (172.18.0.14:19771)
                           ↓
                    Servidor de juego
```

**Respuesta del servidor**:
```
Servidor de juego → Contenedor
                           ↓
                    Docker NAT (SNAT)
                           ↓
                    iptables OUTPUT
                           ↓
                    Established connection
                           ↓
                    ACCEPT (regla #2)
                           ↓
                    Internet → Jugador
```

## ✅ Ventajas

1. **Compatibilidad total**: Docker y Pterodactyl funcionan sin modificaciones
2. **Puertos dinámicos**: Los puertos se abren automáticamente al iniciar servidores
3. **Protección activa**: ANTIDDOS sigue protegiendo contra ataques
4. **Sin conflictos**: Un solo backend de iptables (nft)
5. **MySQL protegido**: Solo accesible desde IP específica

## 🔄 Actualización desde Versión Anterior

Si ya tenías el sistema instalado con `iptables-legacy`:

```bash
# 1. Actualizar código
cd /opt/anti-ddos
sudo git pull origin main

# 2. Configurar nft
sudo chmod +x scripts/setup-nft-compatibility.sh
sudo ./scripts/setup-nft-compatibility.sh

# 3. Reinstalar paquete Python
sudo pip3 install -e . --force-reinstall

# 4. Reiniciar servicios
sudo systemctl restart antiddos-monitor
sudo systemctl restart docker
sudo systemctl restart wings
```

## 📝 Configuración en config.yaml

El archivo de configuración incluye opciones específicas para Docker:

```yaml
advanced:
  # MySQL specific configuration
  mysql:
    port: 3306
    allow_server_public_ip: true
    server_public_ip: "190.57.138.18"
    max_connections_per_ip: 10
    rate_limit: "10/s"
```

Esto asegura que MySQL sea accesible desde la IP pública del servidor (necesario para servicios internos que usan NAT).

## 🎮 Prueba de Funcionamiento

1. **Iniciar un servidor en Pterodactyl**
2. **Verificar que el puerto está escuchando**:
   ```bash
   sudo ss -tulnp | grep PUERTO
   ```
3. **Verificar reglas NAT de Docker**:
   ```bash
   sudo iptables -t nat -L DOCKER -n | grep PUERTO
   ```
4. **Conectar desde el juego** usando `IP:PUERTO`

Si todo funciona, el puerto se abrió automáticamente sin intervención manual. ✅

## 🆘 Soporte

Si encuentras problemas:

1. Verifica el backend: `iptables --version`
2. Revisa logs: `sudo journalctl -u antiddos-monitor -n 50`
3. Verifica Docker: `sudo journalctl -u docker -n 50`
4. Verifica Wings: `sudo journalctl -u wings -n 50`
5. Comprueba reglas: `sudo iptables -L -n -v`

---

**Última actualización**: Compatible con Ubuntu 22.04, Docker 20+, Pterodactyl Wings 1.11+
