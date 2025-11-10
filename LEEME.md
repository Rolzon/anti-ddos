# Sistema Anti-DDoS para Ubuntu 22.04

## 🛡️ Descripción

Sistema completo de protección Anti-DDoS diseñado específicamente para proteger servidores con Pterodactyl y bases de datos.

## ✨ Características Principales

### 1. **Filtrado Dinámico por País (GeoIP)**
- Bloqueo basado en ubicación geográfica
- Modos blacklist (lista negra) y whitelist (lista blanca)
- Activación automática cuando se excede el ancho de banda
- Totalmente configurable

### 2. **Monitoreo de Ancho de Banda**
- Monitoreo en tiempo real de Mbps y PPS (paquetes por segundo)
- Umbrales configurables
- Activación automática de mitigación
- Ventanas de tiempo ajustables

### 3. **Lista Negra Global**
- Bloqueos permanentes y temporales
- Guardado automático en archivo
- Limpieza automática de bloqueos expirados
- Lista blanca con prioridad

### 4. **Filtros DoS**
- Protección contra SYN flood
- Protección contra UDP flood
- Protección contra ICMP flood
- Límites de conexión por IP

### 5. **Protección SSH (estilo Fail2ban)**
- Monitoreo de intentos fallidos
- Bloqueo automático de IPs
- Banner de advertencia personalizable
- Umbrales configurables

### 6. **XCord - Sincronización Encriptada**
- Comunicación encriptada entre servidores
- Sincronización de lista negra en tiempo real
- Autenticación con token
- Arquitectura peer-to-peer

### 7. **Notificaciones Discord 🆕**
- Alertas automáticas de ataques DDoS
- Notificaciones de IPs bloqueadas
- Reportes de mitigación
- Canal público y privado
- Menciones de rol en ataques críticos
- **Todos los bloqueos son automáticos**

## 📋 Requisitos

- Ubuntu 22.04 LTS
- Python 3.10+
- Acceso root/sudo
- iptables

## 🚀 Instalación Rápida

### 1. Transferir archivos al servidor

```bash
# En tu servidor Ubuntu 22.04
cd /opt
# Sube los archivos del proyecto aquí
```

### 2. Ejecutar instalación

```bash
cd /opt/anti-ddos
chmod +x install.sh
sudo ./install.sh
```

### 3. Configuración Inicial CRÍTICA

**⚠️ IMPORTANTE: Antes de iniciar los servicios, agrega tu IP a la lista blanca para no bloquearte:**

```bash
# Reemplaza TU_IP con tu dirección IP real
sudo antiddos-cli whitelist add TU_IP
```

### 4. Configurar interfaz de red

```bash
# Encuentra tu interfaz de red
ip a

# Edita la configuración
sudo nano /etc/antiddos/config.yaml

# Cambia esta línea:
bandwidth:
  interface: eth0  # Cambia a tu interfaz (ej: ens3, enp0s3)
```

### 5. Configurar claves XCord (si usas múltiples servidores)

```bash
# Genera claves seguras
openssl rand -base64 32  # Para encryption_key
openssl rand -hex 32     # Para auth_token

# Edita la configuración
sudo nano /etc/antiddos/config.yaml

# Actualiza estas líneas en TODOS tus servidores:
xcord:
  encryption_key: "TU_CLAVE_GENERADA_AQUI"
  auth_token: "TU_TOKEN_GENERADO_AQUI"
  peers:
    - "IP_SERVIDOR_2:9999"
    - "IP_SERVIDOR_3:9999"
```

### 6. Iniciar servicios

```bash
# Iniciar todos los servicios
sudo systemctl start antiddos-monitor
sudo systemctl start antiddos-ssh
sudo systemctl start antiddos-xcord

# Habilitar en el arranque
sudo systemctl enable antiddos-monitor
sudo systemctl enable antiddos-ssh
sudo systemctl enable antiddos-xcord

# Verificar estado
sudo systemctl status antiddos-monitor
```

## 🔧 Configuración para Pterodactyl y Bases de Datos

### Abrir y Proteger Puerto MySQL/MariaDB (3306)

**Opción 1: Script Automático (Recomendado)**

```bash
# Ejecutar script de configuración
sudo /opt/anti-ddos/scripts/open-mysql-port.sh
```

Este script automáticamente:
- ✅ Abre el puerto 3306
- ✅ Aplica límites de conexión (10 por IP)
- ✅ Configura rate limiting
- ✅ Protege contra SYN flood
- ✅ **Permite acceso desde la IP pública del servidor (190.57.138.18)**
- ✅ Permite acceso desde whitelist

**Opción 2: Manual**

```bash
# Permitir desde la IP pública del servidor
sudo iptables -I ANTIDDOS -s 190.57.138.18 -p tcp --dport 3306 -j ACCEPT

# Limitar conexiones por IP
sudo iptables -I ANTIDDOS -p tcp --dport 3306 -m connlimit --connlimit-above 10 -j REJECT

# Limitar tasa de nuevas conexiones
sudo iptables -I ANTIDDOS -p tcp --dport 3306 --syn -m limit --limit 10/s --limit-burst 20 -j ACCEPT

# Permitir desde localhost
sudo iptables -I ANTIDDOS -s 127.0.0.1 -p tcp --dport 3306 -j ACCEPT

# Guardar reglas
sudo netfilter-persistent save
```

**Ver guía completa:** `docs/OPEN_PORTS.md`

#### ⚠️ Problema: Múltiples Servidores con IP Compartida

Si varios servidores comparten la misma IP pública y no pueden conectarse a MySQL/MariaDB:

**Opción 1: Desbloqueo Completo (Recomendado)**
```bash
# Desbloquear completamente MariaDB/MySQL para tu IP
sudo /opt/anti-ddos/scripts/unlock-mariadb-for-ip.sh
```

**Opción 2: Configuración con Límites Flexibles**
```bash
# Eliminar límites pero mantener protección básica
sudo /opt/anti-ddos/scripts/fix-mysql-shared-ip.sh
```

Este problema ocurre cuando múltiples servidores internos usan NAT y comparten una IP pública. Los scripts eliminan los límites de conexión para tu IP específica (190.57.138.18).

**Ver guía completa:** `docs/MYSQL_SHARED_IP.md`

### Proteger Panel Pterodactyl

```bash
# Agregar IP del panel a lista blanca
sudo antiddos-cli whitelist add IP_DEL_PANEL

# Limitar conexiones HTTP/HTTPS
sudo iptables -I ANTIDDOS -p tcp --dport 80 -m limit --limit 100/s --limit-burst 200 -j ACCEPT
sudo iptables -I ANTIDDOS -p tcp --dport 443 -m limit --limit 100/s --limit-burst 200 -j ACCEPT

# Guardar reglas
sudo netfilter-persistent save
```

### Proteger Wings (Daemon)

```bash
# Agregar IPs de Wings a lista blanca
sudo antiddos-cli whitelist add IP_WINGS_1
sudo antiddos-cli whitelist add IP_WINGS_2

# Proteger puerto API de Wings (8080)
sudo iptables -I ANTIDDOS -p tcp --dport 8080 -m connlimit --connlimit-above 30 -j REJECT

# Guardar reglas
sudo netfilter-persistent save
```

## 📱 Configurar Notificaciones Discord

### Paso 1: Crear Webhook en Discord

1. Ve a tu servidor de Discord
2. Configuración del Servidor → Integraciones → Webhooks
3. Crea un nuevo webhook y copia la URL

### Paso 2: Configurar el Sistema

```bash
sudo nano /etc/antiddos/config.yaml
```

Actualiza la sección de Discord:

```yaml
notifications:
  enabled: true
  discord:
    enabled: true
    webhook_url: "https://discord.com/api/webhooks/TU_WEBHOOK_AQUI"
    notify_attacks: true
    notify_mitigations: true
    notify_blocks: true
```

### Paso 3: Probar Notificaciones

```bash
sudo antiddos-cli discord test
```

**Ver guía completa:** `docs/DISCORD_SETUP.md`

## 📊 Comandos Útiles

### Gestión de Lista Negra

```bash
# Bloquear una IP (automático con notificación Discord)
sudo antiddos-cli blacklist add 1.2.3.4

# Desbloquear una IP
sudo antiddos-cli blacklist remove 1.2.3.4

# Ver IPs bloqueadas
sudo antiddos-cli blacklist list
```

### Gestión de Lista Blanca

```bash
# Agregar IP de confianza
sudo antiddos-cli whitelist add 5.6.7.8

# Remover IP de lista blanca
sudo antiddos-cli whitelist remove 5.6.7.8

# Ver IPs en lista blanca
sudo antiddos-cli whitelist list
```

### Bloqueo por País

```bash
# Bloquear un país (código ISO de 2 letras)
sudo antiddos-cli country block CN  # China
sudo antiddos-cli country block RU  # Rusia

# Desbloquear un país
sudo antiddos-cli country unblock CN

# Ver país de una IP
sudo antiddos-cli country lookup 8.8.8.8
```

### Estadísticas y Monitoreo

```bash
# Ver estadísticas
sudo antiddos-cli stats

# Ver logs en tiempo real
sudo journalctl -u antiddos-monitor -f

# Ver todos los logs
sudo tail -f /var/log/antiddos/*.log

# Recargar configuración
sudo antiddos-cli reload
sudo systemctl restart antiddos-monitor
```

## 🔍 Monitoreo

### Ver estado de servicios

```bash
sudo systemctl status antiddos-monitor
sudo systemctl status antiddos-ssh
sudo systemctl status antiddos-xcord
```

### Ver reglas de firewall

```bash
sudo iptables -L ANTIDDOS -n -v
```

### Ver IPs bloqueadas actualmente

```bash
sudo antiddos-cli blacklist list
```

## ⚠️ Solución de Problemas

### No puedo acceder al servidor después de la instalación

```bash
# 1. Verificar si tu IP está en lista blanca
sudo antiddos-cli whitelist list

# 2. Agregar tu IP
sudo antiddos-cli whitelist add TU_IP

# 3. Si aún no funciona, detener temporalmente
sudo systemctl stop antiddos-monitor
```

### Problemas de conexión a la base de datos

```bash
# Verificar lista blanca
sudo antiddos-cli whitelist list

# Agregar IP del servidor de aplicación
sudo antiddos-cli whitelist add IP_SERVIDOR_APP

# Ver reglas del puerto de base de datos
sudo iptables -L ANTIDDOS -n -v | grep 3306
```

### Servicios no inician

```bash
# Ver logs de error
sudo journalctl -u antiddos-monitor -n 50

# Verificar configuración
python3 -c "import yaml; yaml.safe_load(open('/etc/antiddos/config.yaml'))"

# Verificar permisos
sudo chown -R root:root /etc/antiddos
sudo chmod 600 /etc/antiddos/config.yaml
```

## 📁 Archivos Importantes

```
/etc/antiddos/config.yaml       # Configuración principal
/etc/antiddos/blacklist.txt     # IPs bloqueadas
/etc/antiddos/whitelist.txt     # IPs de confianza
/var/log/antiddos/              # Logs del sistema
```

## 🔐 Mejores Prácticas de Seguridad

1. **Cambia las claves por defecto inmediatamente**
   - XCord encryption_key
   - XCord auth_token

2. **Mantén la lista blanca mínima**
   - Solo IPs de confianza
   - Revisa regularmente

3. **Monitorea los logs diariamente**
   ```bash
   sudo grep -i "banned\|blocked" /var/log/antiddos/*.log
   ```

4. **Haz respaldos de la configuración**
   ```bash
   sudo cp /etc/antiddos/config.yaml ~/antiddos-backup.yaml
   ```

5. **Prueba en staging antes de producción**

6. **Mantén el sistema actualizado**
   ```bash
   sudo apt update && sudo apt upgrade
   ```

## 📚 Documentación Adicional

- `README.md` - Documentación completa en inglés
- `QUICKSTART.md` - Guía de inicio rápido
- `docs/ADVANCED.md` - Configuración avanzada
- `docs/PTERODACTYL_DEPLOYMENT.md` - Guía específica para Pterodactyl
- `PROJECT_STRUCTURE.md` - Estructura del proyecto

## 🆘 Procedimientos de Emergencia

### Apagado completo del sistema

Si Anti-DDoS está causando problemas:

```bash
# Detener todos los servicios
sudo systemctl stop antiddos-monitor antiddos-ssh antiddos-xcord

# Remover reglas de firewall
sudo iptables -D INPUT -j ANTIDDOS
sudo iptables -F ANTIDDOS
sudo iptables -X ANTIDDOS
```

### Recuperación rápida

```bash
# Restaurar desde respaldo
sudo tar -xzf /backup/antiddos-YYYYMMDD.tar.gz -C /

# Reiniciar servicios
sudo systemctl start antiddos-monitor antiddos-ssh antiddos-xcord
```

## 🔄 Desinstalación

Si necesitas desinstalar el sistema:

```bash
cd /opt/anti-ddos
sudo ./uninstall.sh
```

## 📞 Soporte

Para problemas o preguntas:
1. Revisa los logs: `/var/log/antiddos/`
2. Verifica la configuración: `/etc/antiddos/config.yaml`
3. Consulta la documentación en `docs/`

## 📝 Notas Importantes

- **Este sistema requiere acceso root** para modificar iptables y monitorear el sistema
- **Siempre agrega tu IP a la lista blanca** antes de activar filtros
- **Las claves XCord deben ser idénticas** en todos los servidores
- **Prueba en un entorno de staging** antes de implementar en producción
- **Mantén respaldos** de tu configuración

## ✅ Checklist de Implementación

- [ ] Sistema instalado correctamente
- [ ] Tu IP agregada a lista blanca
- [ ] Interfaz de red configurada
- [ ] Claves XCord cambiadas (si aplica)
- [ ] IPs de servidores confiables en lista blanca
- [ ] Reglas de base de datos aplicadas
- [ ] Reglas de Pterodactyl aplicadas
- [ ] Servicios iniciados y habilitados
- [ ] Logs monitoreados
- [ ] Respaldo de configuración creado
- [ ] Pruebas de conectividad realizadas

## 🎯 Próximos Pasos

1. Monitorea los logs durante las primeras 24 horas
2. Ajusta umbrales según tu tráfico real
3. Documenta IPs bloqueadas legítimas (falsos positivos)
4. Configura alertas por email/webhook
5. Establece rutina de mantenimiento semanal

---

**¡Tu servidor ahora está protegido contra ataques DDoS!** 🛡️
