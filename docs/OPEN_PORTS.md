# Guía para Abrir Puertos en el Sistema Anti-DDoS

## 📖 Introducción

El sistema Anti-DDoS bloquea tráfico sospechoso por defecto. Esta guía te muestra cómo abrir puertos específicos manteniendo la protección contra ataques.

## 🔓 Puerto 3306 (MySQL/MariaDB)

### Método 1: Script Automático (Recomendado)

```bash
# Hacer ejecutable el script
sudo chmod +x /opt/anti-ddos/scripts/open-mysql-port.sh

# Ejecutar
sudo /opt/anti-ddos/scripts/open-mysql-port.sh
```

Este script:
- ✅ Abre el puerto 3306
- ✅ Aplica límites de conexión (10 por IP)
- ✅ Configura rate limiting (10/segundo)
- ✅ Protege contra SYN flood
- ✅ Permite acceso desde IPs en whitelist
- ✅ Guarda las reglas automáticamente

### Método 2: Manual con iptables

```bash
# Permitir conexiones establecidas
sudo iptables -I ANTIDDOS -p tcp --dport 3306 -m state --state ESTABLISHED,RELATED -j ACCEPT

# Limitar conexiones por IP
sudo iptables -I ANTIDDOS -p tcp --dport 3306 -m connlimit --connlimit-above 10 -j REJECT

# Rate limit
sudo iptables -I ANTIDDOS -p tcp --dport 3306 --syn -m limit --limit 10/s --limit-burst 20 -j ACCEPT

# Permitir desde localhost
sudo iptables -I ANTIDDOS -s 127.0.0.1 -p tcp --dport 3306 -j ACCEPT

# Guardar reglas
sudo netfilter-persistent save
```

### Método 3: Agregar a la Configuración

Edita `/etc/antiddos/config.yaml`:

```yaml
advanced:
  allowed_ports:
    - 3306  # MySQL/MariaDB
```

Luego reinicia el servicio:

```bash
sudo systemctl restart antiddos-monitor
```

## 🔐 Seguridad Adicional para MySQL

### 1. Configurar Bind Address

Edita `/etc/mysql/mysql.conf.d/mysqld.cnf`:

```ini
[mysqld]
# Escuchar en todas las interfaces
bind-address = 0.0.0.0

# O solo en una IP específica
bind-address = 192.168.1.100
```

Reinicia MySQL:

```bash
sudo systemctl restart mysql
```

### 2. Agregar IPs de Aplicaciones a Whitelist

```bash
# Agregar IP del servidor de aplicación
sudo antiddos-cli whitelist add 192.168.1.50

# Agregar IP del panel Pterodactyl
sudo antiddos-cli whitelist add 192.168.1.10

# Verificar whitelist
sudo antiddos-cli whitelist list
```

### 3. Configurar Usuario MySQL con Host Específico

```sql
-- Conectar a MySQL
mysql -u root -p

-- Crear usuario solo para IP específica
CREATE USER 'app_user'@'192.168.1.50' IDENTIFIED BY 'password_seguro';
GRANT ALL PRIVILEGES ON app_database.* TO 'app_user'@'192.168.1.50';
FLUSH PRIVILEGES;

-- Verificar usuarios
SELECT user, host FROM mysql.user;
```

### 4. Habilitar SSL/TLS (Recomendado)

```bash
# Verificar si MySQL tiene SSL habilitado
mysql -u root -p -e "SHOW VARIABLES LIKE '%ssl%';"

# Generar certificados (si no existen)
sudo mysql_ssl_rsa_setup

# Reiniciar MySQL
sudo systemctl restart mysql
```

Configurar usuario para requerir SSL:

```sql
ALTER USER 'app_user'@'192.168.1.50' REQUIRE SSL;
FLUSH PRIVILEGES;
```

## 🔍 Verificación

### Verificar que el Puerto está Abierto

```bash
# Ver reglas de iptables para el puerto 3306
sudo iptables -L ANTIDDOS -n -v | grep 3306

# Ver conexiones activas
sudo ss -tnp | grep :3306

# Probar conexión desde otro servidor
mysql -h IP_DEL_SERVIDOR -u usuario -p
```

### Verificar Límites Aplicados

```bash
# Ver estadísticas de las reglas
sudo iptables -L ANTIDDOS -n -v --line-numbers | grep 3306

# Monitorear conexiones en tiempo real
watch -n 1 'sudo ss -tn | grep :3306 | wc -l'
```

## 🔓 Otros Puertos Comunes

### PostgreSQL (Puerto 5432)

```bash
# Abrir puerto PostgreSQL
sudo iptables -I ANTIDDOS -p tcp --dport 5432 -m connlimit --connlimit-above 10 -j REJECT
sudo iptables -I ANTIDDOS -p tcp --dport 5432 --syn -m limit --limit 10/s -j ACCEPT
sudo iptables -I ANTIDDOS -s 127.0.0.1 -p tcp --dport 5432 -j ACCEPT
sudo netfilter-persistent save
```

### Redis (Puerto 6379)

```bash
# Abrir puerto Redis
sudo iptables -I ANTIDDOS -p tcp --dport 6379 -m connlimit --connlimit-above 20 -j REJECT
sudo iptables -I ANTIDDOS -p tcp --dport 6379 --syn -m limit --limit 20/s -j ACCEPT
sudo iptables -I ANTIDDOS -s 127.0.0.1 -p tcp --dport 6379 -j ACCEPT
sudo netfilter-persistent save
```

### MongoDB (Puerto 27017)

```bash
# Abrir puerto MongoDB
sudo iptables -I ANTIDDOS -p tcp --dport 27017 -m connlimit --connlimit-above 15 -j REJECT
sudo iptables -I ANTIDDOS -p tcp --dport 27017 --syn -m limit --limit 15/s -j ACCEPT
sudo iptables -I ANTIDDOS -s 127.0.0.1 -p tcp --dport 27017 -j ACCEPT
sudo netfilter-persistent save
```

### Puertos de Juegos (Ejemplo: Minecraft)

```bash
# Minecraft (25565)
sudo iptables -I ANTIDDOS -p tcp --dport 25565 -m limit --limit 50/s --limit-burst 100 -j ACCEPT
sudo iptables -I ANTIDDOS -p udp --dport 25565 -m limit --limit 100/s --limit-burst 200 -j ACCEPT
sudo netfilter-persistent save
```

## 📊 Monitoreo

### Ver Tráfico del Puerto

```bash
# Ver paquetes en tiempo real
sudo tcpdump -i eth0 port 3306

# Ver estadísticas de iptables
sudo watch -n 1 'iptables -L ANTIDDOS -n -v | grep 3306'

# Ver conexiones activas con detalles
sudo netstat -tnp | grep :3306
```

### Logs de Conexiones

```bash
# Ver logs de MySQL
sudo tail -f /var/log/mysql/error.log

# Ver intentos de conexión bloqueados
sudo journalctl -u antiddos-monitor | grep 3306

# Ver logs del firewall
sudo tail -f /var/log/kern.log | grep ANTIDDOS
```

## 🚨 Solución de Problemas

### No puedo conectarme a MySQL

1. **Verificar que MySQL está escuchando:**
   ```bash
   sudo netstat -tlnp | grep 3306
   ```

2. **Verificar bind-address:**
   ```bash
   sudo grep bind-address /etc/mysql/mysql.conf.d/mysqld.cnf
   ```

3. **Verificar reglas de iptables:**
   ```bash
   sudo iptables -L ANTIDDOS -n -v | grep 3306
   ```

4. **Verificar whitelist:**
   ```bash
   sudo antiddos-cli whitelist list
   ```

5. **Probar desde localhost:**
   ```bash
   mysql -u root -p -h 127.0.0.1
   ```

### Conexiones siendo bloqueadas

```bash
# Ver IPs bloqueadas
sudo antiddos-cli blacklist list

# Agregar IP a whitelist
sudo antiddos-cli whitelist add IP_CLIENTE

# Ver logs en tiempo real
sudo journalctl -u antiddos-monitor -f
```

### Demasiadas conexiones rechazadas

Aumentar límites en iptables:

```bash
# Aumentar límite de conexiones por IP (de 10 a 20)
sudo iptables -R ANTIDDOS [NUMERO_REGLA] -p tcp --dport 3306 -m connlimit --connlimit-above 20 -j REJECT

# Aumentar rate limit (de 10/s a 20/s)
sudo iptables -R ANTIDDOS [NUMERO_REGLA] -p tcp --dport 3306 --syn -m limit --limit 20/s --limit-burst 40 -j ACCEPT

# Guardar
sudo netfilter-persistent save
```

## 🔒 Mejores Prácticas

### 1. Principio de Mínimo Privilegio

- Solo abre puertos necesarios
- Usa whitelist para IPs conocidas
- Configura usuarios MySQL con hosts específicos

### 2. Monitoreo Continuo

- Revisa logs regularmente
- Monitorea conexiones activas
- Configura alertas Discord para actividad sospechosa

### 3. Actualizaciones

- Mantén MySQL actualizado
- Actualiza reglas de firewall según necesidad
- Revisa whitelist periódicamente

### 4. Backup de Configuración

```bash
# Backup de reglas iptables
sudo iptables-save > ~/iptables-backup-$(date +%Y%m%d).rules

# Backup de configuración MySQL
sudo cp /etc/mysql/mysql.conf.d/mysqld.cnf ~/mysqld.cnf.backup

# Backup de whitelist
sudo cp /etc/antiddos/whitelist.txt ~/whitelist-backup.txt
```

## 📋 Checklist de Seguridad

Antes de abrir el puerto 3306 en producción:

- [ ] Puerto abierto con límites de conexión
- [ ] Rate limiting configurado
- [ ] IPs de aplicaciones en whitelist
- [ ] MySQL configurado con bind-address correcto
- [ ] Usuarios MySQL con hosts específicos
- [ ] SSL/TLS habilitado (recomendado)
- [ ] Contraseñas fuertes configuradas
- [ ] Logs monitoreados
- [ ] Alertas Discord configuradas
- [ ] Backup de configuración realizado
- [ ] Pruebas de conexión exitosas
- [ ] Documentación actualizada

## 🆘 Emergencia: Cerrar Puerto Rápidamente

Si detectas un ataque:

```bash
# Cerrar puerto 3306 inmediatamente
sudo iptables -I ANTIDDOS -p tcp --dport 3306 -j DROP

# O detener MySQL temporalmente
sudo systemctl stop mysql

# Revisar logs
sudo journalctl -u antiddos-monitor -n 100

# Ver IPs atacantes
sudo ss -tn | grep :3306
```

---

**Recuerda:** La seguridad es un proceso continuo. Monitorea, actualiza y ajusta según sea necesario.
