# Lista de Verificación para Despliegue / Deployment Checklist

## Pre-Instalación / Pre-Installation

### Requisitos del Sistema / System Requirements
- [ ] Ubuntu 22.04 LTS instalado / installed
- [ ] Acceso root o sudo / Root or sudo access
- [ ] Conexión a Internet / Internet connection
- [ ] Al menos 1GB RAM disponible / At least 1GB RAM available
- [ ] 500MB espacio en disco / 500MB disk space

### Información Necesaria / Required Information
- [ ] Tu dirección IP administrativa / Your admin IP address: `_______________`
- [ ] Interfaz de red principal / Primary network interface: `_______________`
- [ ] IPs de servidores confiables / Trusted server IPs:
  - Panel Pterodactyl: `_______________`
  - Wings/Daemon 1: `_______________`
  - Wings/Daemon 2: `_______________`
  - Base de datos: `_______________`
  - Otros / Others: `_______________`

### Respaldo / Backup
- [ ] Respaldo de configuración actual de iptables / Current iptables backup
  ```bash
  sudo iptables-save > ~/iptables-backup-$(date +%Y%m%d).rules
  ```
- [ ] Respaldo de configuración SSH / SSH config backup
  ```bash
  sudo cp /etc/ssh/sshd_config ~/sshd_config.backup
  ```

## Instalación / Installation

### Paso 1: Transferir Archivos / Transfer Files
- [ ] Archivos del proyecto copiados a `/opt/anti-ddos`
- [ ] Permisos verificados / Permissions verified
  ```bash
  sudo chown -R root:root /opt/anti-ddos
  ```

### Paso 2: Ejecutar Instalación / Run Installation
- [ ] Scripts hechos ejecutables / Scripts made executable
  ```bash
  cd /opt/anti-ddos
  chmod +x install.sh test_installation.sh scripts/*.sh
  ```
- [ ] Instalación ejecutada / Installation run
  ```bash
  sudo ./install.sh
  ```
- [ ] Prueba de instalación exitosa / Installation test passed
  ```bash
  sudo ./test_installation.sh
  ```

### Paso 3: Configuración Inicial / Initial Configuration
- [ ] Asistente de configuración ejecutado / Configuration wizard run
  ```bash
  sudo ./scripts/quick-setup.sh
  ```
  
  O configuración manual / Or manual configuration:
  
- [ ] Archivo de configuración editado / Config file edited
  ```bash
  sudo nano /etc/antiddos/config.yaml
  ```
- [ ] Interfaz de red configurada / Network interface configured
- [ ] Umbrales de ancho de banda ajustados / Bandwidth thresholds adjusted
- [ ] Países bloqueados configurados / Blocked countries configured

### Paso 4: Lista Blanca Crítica / Critical Whitelist
⚠️ **MUY IMPORTANTE / VERY IMPORTANT** ⚠️

- [ ] Tu IP agregada a lista blanca / Your IP whitelisted
  ```bash
  sudo antiddos-cli whitelist add YOUR_IP
  ```
- [ ] IPs de servidores confiables agregadas / Trusted server IPs added
  ```bash
  sudo antiddos-cli whitelist add PANEL_IP
  sudo antiddos-cli whitelist add WINGS_IP
  sudo antiddos-cli whitelist add DB_IP
  ```
- [ ] Lista blanca verificada / Whitelist verified
  ```bash
  sudo antiddos-cli whitelist list
  ```

## Configuración Específica / Specific Configuration

### Para Base de Datos / For Database Server
- [ ] Reglas de MySQL/MariaDB aplicadas / MySQL/MariaDB rules applied
  ```bash
  sudo iptables -I ANTIDDOS -p tcp --dport 3306 -m connlimit --connlimit-above 10 -j REJECT
  sudo netfilter-persistent save
  ```
- [ ] IPs de aplicaciones en lista blanca / Application IPs whitelisted
- [ ] Conexiones de prueba verificadas / Test connections verified

### Para Panel Pterodactyl / For Pterodactyl Panel
- [ ] Reglas HTTP/HTTPS aplicadas / HTTP/HTTPS rules applied
- [ ] Límites de conexión configurados / Connection limits configured
- [ ] Acceso al panel verificado / Panel access verified

### Para Wings/Daemon
- [ ] Puerto API protegido (8080) / API port protected (8080)
- [ ] Comunicación con panel verificada / Panel communication verified
- [ ] Servidores de juego funcionando / Game servers working

### XCord (Multi-Servidor) / XCord (Multi-Server)
Si usas múltiples servidores / If using multiple servers:

- [ ] Claves de encriptación generadas / Encryption keys generated
  ```bash
  openssl rand -base64 32  # Encryption key
  openssl rand -hex 32     # Auth token
  ```
- [ ] Mismas claves en todos los servidores / Same keys on all servers
- [ ] Puerto 9999 abierto entre servidores / Port 9999 open between servers
- [ ] Peers configurados en config.yaml / Peers configured in config.yaml
- [ ] Sincronización verificada / Sync verified

## Inicio de Servicios / Service Startup

### Iniciar Servicios / Start Services
- [ ] Monitor iniciado / Monitor started
  ```bash
  sudo systemctl start antiddos-monitor
  ```
- [ ] SSH protection iniciado / SSH protection started
  ```bash
  sudo systemctl start antiddos-ssh
  ```
- [ ] XCord iniciado (si aplica) / XCord started (if applicable)
  ```bash
  sudo systemctl start antiddos-xcord
  ```

### Habilitar en Arranque / Enable on Boot
- [ ] Servicios habilitados / Services enabled
  ```bash
  sudo systemctl enable antiddos-monitor antiddos-ssh antiddos-xcord
  ```

### Verificar Estado / Check Status
- [ ] Todos los servicios activos / All services active
  ```bash
  sudo systemctl status antiddos-monitor
  sudo systemctl status antiddos-ssh
  sudo systemctl status antiddos-xcord
  ```

## Pruebas / Testing

### Pruebas de Conectividad / Connectivity Tests
- [ ] Acceso SSH funciona / SSH access works
- [ ] Acceso al panel web funciona / Web panel access works
- [ ] Base de datos accesible / Database accessible
- [ ] Servidores de juego funcionan / Game servers work
- [ ] Comunicación entre servidores OK / Inter-server communication OK

### Pruebas de Protección / Protection Tests
- [ ] Reglas de firewall activas / Firewall rules active
  ```bash
  sudo iptables -L ANTIDDOS -n -v
  ```
- [ ] Estadísticas funcionando / Statistics working
  ```bash
  sudo antiddos-cli stats
  ```
- [ ] Logs generándose / Logs generating
  ```bash
  sudo tail -f /var/log/antiddos/antiddos.log
  ```

### Prueba de Bloqueo / Block Test
- [ ] Bloqueo manual probado / Manual block tested
  ```bash
  sudo antiddos-cli blacklist add 1.2.3.4
  sudo antiddos-cli blacklist list
  sudo antiddos-cli blacklist remove 1.2.3.4
  ```

## Monitoreo Inicial / Initial Monitoring

### Primeras 24 Horas / First 24 Hours
- [ ] Logs monitoreados cada hora / Logs monitored hourly
- [ ] Sin falsos positivos detectados / No false positives detected
- [ ] Tráfico legítimo funcionando / Legitimate traffic working
- [ ] Umbrales ajustados si necesario / Thresholds adjusted if needed

### Ajustes Post-Despliegue / Post-Deployment Adjustments
- [ ] Falsos positivos documentados / False positives documented
- [ ] IPs legítimas agregadas a lista blanca / Legitimate IPs whitelisted
- [ ] Umbrales optimizados / Thresholds optimized
- [ ] Países ajustados si necesario / Countries adjusted if needed

## Documentación / Documentation

### Información Guardada / Saved Information
- [ ] Claves XCord guardadas de forma segura / XCord keys saved securely
- [ ] Configuración respaldada / Configuration backed up
  ```bash
  sudo cp /etc/antiddos/config.yaml ~/antiddos-config-backup.yaml
  ```
- [ ] IPs importantes documentadas / Important IPs documented
- [ ] Procedimientos de emergencia revisados / Emergency procedures reviewed

### Documentación del Equipo / Team Documentation
- [ ] Equipo informado sobre el sistema / Team informed about system
- [ ] Procedimientos de whitelist documentados / Whitelist procedures documented
- [ ] Contactos de emergencia actualizados / Emergency contacts updated

## Mantenimiento Programado / Scheduled Maintenance

### Tareas Diarias / Daily Tasks
- [ ] Revisar logs de bloqueos / Review block logs
  ```bash
  sudo grep -i "banned\|blocked" /var/log/antiddos/*.log
  ```
- [ ] Verificar estadísticas / Check statistics
  ```bash
  sudo antiddos-cli stats
  ```

### Tareas Semanales / Weekly Tasks
- [ ] Revisar lista blanca / Review whitelist
- [ ] Limpiar bloqueos temporales expirados / Clean expired temp bans
- [ ] Verificar estado de servicios / Check service status

### Tareas Mensuales / Monthly Tasks
- [ ] Actualizar base de datos GeoIP / Update GeoIP database
  ```bash
  sudo antiddos-cli geoip update
  ```
- [ ] Revisar y optimizar umbrales / Review and optimize thresholds
- [ ] Respaldo de configuración / Configuration backup
- [ ] Revisar logs de errores / Review error logs

## Procedimientos de Emergencia / Emergency Procedures

### Si Te Bloqueas / If You Lock Yourself Out
```bash
# Desde consola del servidor / From server console
sudo systemctl stop antiddos-monitor
sudo iptables -D INPUT -j ANTIDDOS
sudo iptables -F ANTIDDOS
```

### Si Hay Problemas de Conectividad / If Connectivity Issues
```bash
# Desactivar temporalmente / Temporarily disable
sudo systemctl stop antiddos-monitor antiddos-ssh antiddos-xcord

# Verificar reglas / Check rules
sudo iptables -L ANTIDDOS -n -v

# Agregar IP a lista blanca / Add IP to whitelist
sudo antiddos-cli whitelist add PROBLEM_IP
```

### Restaurar desde Respaldo / Restore from Backup
```bash
# Restaurar configuración / Restore configuration
sudo cp ~/antiddos-config-backup.yaml /etc/antiddos/config.yaml

# Reiniciar servicios / Restart services
sudo systemctl restart antiddos-monitor antiddos-ssh antiddos-xcord
```

## Contactos y Recursos / Contacts and Resources

### Documentación / Documentation
- [ ] README.md revisado / README.md reviewed
- [ ] LEEME.md revisado (español) / LEEME.md reviewed (Spanish)
- [ ] QUICKSTART.md revisado / QUICKSTART.md reviewed
- [ ] PTERODACTYL_DEPLOYMENT.md revisado / PTERODACTYL_DEPLOYMENT.md reviewed

### Herramientas de Diagnóstico / Diagnostic Tools
- [ ] Script de diagnóstico probado / Diagnostic script tested
  ```bash
  sudo ./scripts/diagnose.sh
  ```

### Soporte / Support
- Logs: `/var/log/antiddos/`
- Configuración: `/etc/antiddos/config.yaml`
- CLI: `antiddos-cli --help`

## Firma de Aprobación / Sign-Off

### Instalación Completada Por / Installation Completed By
- Nombre / Name: `_______________`
- Fecha / Date: `_______________`
- Firma / Signature: `_______________`

### Verificación / Verification
- Verificado por / Verified by: `_______________`
- Fecha / Date: `_______________`
- Firma / Signature: `_______________`

### Notas Adicionales / Additional Notes
```
_____________________________________________
_____________________________________________
_____________________________________________
_____________________________________________
```

---

## ✅ Checklist Rápido / Quick Checklist

**Antes de declarar el despliegue completo, verifica:**

- [ ] ✅ Instalación exitosa
- [ ] ✅ Tu IP en lista blanca
- [ ] ✅ Servicios corriendo
- [ ] ✅ Conectividad verificada
- [ ] ✅ Logs monitoreados
- [ ] ✅ Respaldos creados
- [ ] ✅ Documentación completa
- [ ] ✅ Equipo informado

**Si todos los items están marcados, el despliegue está completo! 🎉**
