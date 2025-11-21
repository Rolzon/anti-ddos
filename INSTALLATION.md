# Guía de Instalación Completa - Anti-DDoS

## Requisitos del Sistema

- **OS**: Ubuntu 20.04+ / Debian 11+
- **Permisos**: Root (sudo)
- **Software**: Docker (si usas contenedores), Python 3.8+
- **Red**: Interfaz de red configurada (ej: `dr0`, `eth0`)

## Instalación Automática (Recomendado)

### 1. Subir el proyecto al servidor

```bash
# Desde tu máquina local, sube el proyecto
scp -r anti-ddos/ usuario@tu-servidor:/opt/

# O clona desde git si tienes el repo
# git clone https://github.com/tu-usuario/anti-ddos.git /opt/anti-ddos
```

### 2. Ejecutar script de instalación

```bash
# Conectarse al servidor
ssh usuario@tu-servidor

# Ir al directorio del proyecto
cd /opt/anti-ddos

# Dar permisos de ejecución
chmod +x reinstall.sh verify_installation.sh

# Ejecutar instalación
sudo ./reinstall.sh
```

El script automáticamente:
- ✅ Detiene servicios anteriores
- ✅ Instala dependencias (iptables-nft, Python, etc.)
- ✅ Instala el proyecto Python
- ✅ Crea directorios en `/etc/antiddos`, `/var/log/antiddos`
- ✅ Configura permisos correctos
- ✅ Instala servicio systemd

### 3. Verificar instalación

```bash
sudo ./verify_installation.sh
```

Deberías ver todo en verde (✓). Si hay errores, revisa los logs.

### 4. Configurar según tu entorno

```bash
# Editar configuración
sudo nano /etc/antiddos/config.yaml
```

**Configuraciones críticas:**

```yaml
# Interfaz principal (donde medir tráfico)
bandwidth:
  interface: "dr0"  # Cambia por tu interfaz: eth0, ens3, etc.

# Si usas Docker
services:
  auto_discovery:
    mode: "docker"
    docker:
      binary: "/usr/bin/docker"
      default_interface: "dr0"  # Misma que bandwidth.interface

# Notificaciones Discord (opcional)
discord:
  enabled: true
  webhook_url: "https://discord.com/api/webhooks/..."

# IPs de confianza (nunca bloquear)
whitelist:
  enabled: true
  ips:
    - "tu.ip.publica.aqui"
    - "127.0.0.1"
```

### 5. Iniciar el servicio

```bash
# Iniciar
sudo systemctl start antiddos-monitor

# Habilitar al inicio
sudo systemctl enable antiddos-monitor

# Ver logs en tiempo real
sudo journalctl -u antiddos-monitor -f

# Ver estado
antiddos status
```

## Instalación Manual (Paso a Paso)

### 1. Instalar dependencias

```bash
sudo apt update
sudo apt install -y iptables nftables python3-pip python3-venv net-tools
```

### 2. Configurar iptables-nft

```bash
sudo update-alternatives --set iptables /usr/sbin/iptables-nft
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-nft
```

### 3. Instalar proyecto Python

```bash
cd /opt/anti-ddos
sudo pip3 install -e .
```

### 4. Crear estructura de directorios

```bash
sudo mkdir -p /etc/antiddos
sudo mkdir -p /var/log/antiddos
sudo mkdir -p /var/lib/antiddos

# Copiar configuración
sudo cp config/config.yaml /etc/antiddos/

# Crear archivos vacíos
sudo touch /etc/antiddos/blacklist.txt
sudo touch /etc/antiddos/whitelist.txt

# Permisos
sudo chmod 755 /etc/antiddos
sudo chmod 644 /etc/antiddos/*.yaml /etc/antiddos/*.txt
sudo chmod 755 /var/log/antiddos /var/lib/antiddos
```

### 5. Crear servicio systemd

```bash
sudo nano /etc/systemd/system/antiddos-monitor.service
```

Contenido:

```ini
[Unit]
Description=Anti-DDoS Monitor Service
After=network.target docker.service
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/usr/local/bin/antiddos monitor
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=antiddos

# Capacidades necesarias para iptables
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
```

## Verificación Post-Instalación

### 1. Comprobar que el comando funciona

```bash
antiddos --help
antiddos status
```

### 2. Verificar reglas iptables

```bash
# Debe mostrar cadena ANTIDDOS
sudo iptables -L ANTIDDOS -n -v

# Debe aparecer en INPUT y FORWARD
sudo iptables -L INPUT -n | grep ANTIDDOS
sudo iptables -L FORWARD -n | grep ANTIDDOS
```

### 3. Ver logs del servicio

```bash
# Últimas 50 líneas
sudo journalctl -u antiddos-monitor -n 50

# Tiempo real
sudo journalctl -u antiddos-monitor -f
```

### 4. Probar detección (opcional)

```bash
# Ver servicios descubiertos
antiddos status

# Ver estadísticas en tiempo real
watch -n 2 'antiddos status'
```

## Comandos Útiles

```bash
# Gestión del servicio
sudo systemctl start antiddos-monitor    # Iniciar
sudo systemctl stop antiddos-monitor     # Detener
sudo systemctl restart antiddos-monitor  # Reiniciar
sudo systemctl status antiddos-monitor   # Ver estado

# Logs
sudo journalctl -u antiddos-monitor -f           # Tiempo real
sudo journalctl -u antiddos-monitor -n 100       # Últimas 100 líneas
sudo journalctl -u antiddos-monitor --since today # Hoy

# Configuración
sudo nano /etc/antiddos/config.yaml      # Editar config
antiddos status                          # Ver estado actual

# Reglas de firewall
sudo iptables -L ANTIDDOS -n -v --line-numbers  # Ver cadena principal
sudo iptables -L INPUT -n -v | grep ANTIDDOS    # Ver en INPUT
sudo iptables -L FORWARD -n -v | grep ANTIDDOS  # Ver en FORWARD (Docker)

# Blacklist/Whitelist manual
echo "1.2.3.4" | sudo tee -a /etc/antiddos/blacklist.txt
echo "5.6.7.8" | sudo tee -a /etc/antiddos/whitelist.txt
sudo systemctl restart antiddos-monitor  # Aplicar cambios
```

## Solución de Problemas

### Servicio no inicia

```bash
# Ver error específico
sudo journalctl -u antiddos-monitor -n 50 --no-pager

# Verificar permisos
sudo ./verify_installation.sh

# Probar comando manual
sudo antiddos monitor
```

### IPs no se bloquean

```bash
# 1. Verificar que la cadena existe en FORWARD (Docker)
sudo iptables -L FORWARD -n -v | grep ANTIDDOS

# 2. Ver si hay reglas de bloqueo
sudo iptables -L ANTIDDOS -n -v | grep DROP

# 3. Ver logs de detección
sudo journalctl -u antiddos-monitor -f | grep "bloqueada\|blocked"

# 4. Verificar configuración UDP auto-block
grep -A 5 "auto_udp_block" /etc/antiddos/config.yaml
```

### No detecta contenedores Docker

```bash
# 1. Verificar que Docker funciona
docker ps

# 2. Verificar configuración
grep -A 10 "auto_discovery" /etc/antiddos/config.yaml

# 3. Ver logs de discovery
sudo journalctl -u antiddos-monitor | grep -i "docker\|descubierto"
```

### Advertencia de iptables backend

```bash
# Asegúrate de que el PATH incluye /usr/sbin
sudo systemctl edit antiddos-monitor.service

# Agrega:
[Service]
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Luego:
sudo systemctl daemon-reload
sudo systemctl restart antiddos-monitor
```

## Actualización

Para actualizar a una nueva versión:

```bash
cd /opt/anti-ddos
git pull  # Si usas git
sudo ./reinstall.sh
```

## Desinstalación

```bash
sudo systemctl stop antiddos-monitor
sudo systemctl disable antiddos-monitor
sudo rm /etc/systemd/system/antiddos-monitor.service
sudo systemctl daemon-reload
sudo pip3 uninstall antiddos -y

# Opcional: eliminar configuración
sudo rm -rf /etc/antiddos
sudo rm -rf /var/log/antiddos
sudo rm -rf /var/lib/antiddos
```

## Soporte

Si encuentras problemas:

1. Ejecuta `sudo ./verify_installation.sh` y comparte la salida
2. Revisa logs: `sudo journalctl -u antiddos-monitor -n 100`
3. Verifica configuración: `cat /etc/antiddos/config.yaml`
4. Comprueba reglas iptables: `sudo iptables -L ANTIDDOS -n -v`
