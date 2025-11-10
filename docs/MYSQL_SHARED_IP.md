# Solución: Múltiples Servidores con IP Pública Compartida

## 🔴 Problema

Tienes varios servidores que comparten la misma IP pública (190.57.138.18) debido a NAT o proxy, y no pueden conectarse a MySQL porque el firewall limita las conexiones por IP.

### Síntomas:
- ✗ Conexiones MySQL rechazadas
- ✗ Error: "Too many connections"
- ✗ Timeout al conectar desde servidores internos
- ✗ Funciona desde localhost pero no desde IP pública

## ✅ Solución Rápida

### Opción 1: Script Automático (Recomendado)

```bash
# En el servidor con MySQL
cd /opt/anti-ddos
sudo chmod +x scripts/fix-mysql-shared-ip.sh
sudo ./scripts/fix-mysql-shared-ip.sh
```

Este script:
- ✅ Elimina límites de conexión para la IP compartida
- ✅ Permite acceso ilimitado al puerto 3306
- ✅ Agrega la IP a whitelist
- ✅ Mantiene protecciones para otras IPs

### Opción 2: Comandos Manuales

```bash
# Detectar sistema de firewall
if command -v iptables-legacy &> /dev/null && iptables-legacy -L -n &>/dev/null 2>&1; then
    IPTABLES="iptables-legacy"
else
    IPTABLES="iptables"
fi

# Permitir acceso ilimitado desde la IP compartida (PRIORIDAD MÁXIMA)
sudo $IPTABLES -I ANTIDDOS 1 -s 190.57.138.18 -p tcp --dport 3306 -j ACCEPT

# Agregar a whitelist
echo "190.57.138.18  # IP pública compartida" | sudo tee -a /etc/antiddos/whitelist.txt

# Guardar reglas
sudo netfilter-persistent save
```

## 🔍 Verificación

### Ver Reglas Aplicadas

```bash
# Ver todas las reglas para tu IP
sudo iptables-legacy -L ANTIDDOS -n -v --line-numbers | grep 190.57.138.18

# Deberías ver algo como:
# 1    0     0 ACCEPT     tcp  --  *  *  190.57.138.18  0.0.0.0/0  tcp dpt:3306
```

### Probar Conexión

```bash
# Desde cualquier servidor con la IP compartida
mysql -h 190.57.138.18 -u usuario -p

# Ver conexiones activas
sudo ss -tnp | grep :3306

# Ver cuántas conexiones hay desde tu IP
sudo ss -tn | grep :3306 | grep 190.57.138.18 | wc -l
```

## 📊 Cómo Funciona

### Antes (Con Límites)

```
Regla #5: REJECT si > 10 conexiones desde 190.57.138.18
Regla #8: Rate limit 10/s para 190.57.138.18
```

**Problema:** Servidor A, B y C comparten la misma IP → Solo 10 conexiones totales permitidas

### Después (Sin Límites)

```
Regla #1: ACCEPT todo desde 190.57.138.18 al puerto 3306 (PRIORIDAD)
Regla #5: REJECT si > 10 conexiones (no aplica a 190.57.138.18)
Regla #8: Rate limit 10/s (no aplica a 190.57.138.18)
```

**Solución:** La regla #1 tiene prioridad, permite todo antes de evaluar límites

## 🛡️ Seguridad

### ¿Es Seguro?

**SÍ**, porque:
- ✅ Solo aplica a TU IP pública (190.57.138.18)
- ✅ Solo para el puerto 3306 (MySQL)
- ✅ Otras IPs siguen teniendo límites
- ✅ Protecciones DDoS siguen activas para otras IPs

### Recomendaciones Adicionales

1. **Usar Autenticación Fuerte en MySQL**
   ```sql
   -- Crear usuarios con hosts específicos
   CREATE USER 'app'@'190.57.138.18' IDENTIFIED BY 'password_fuerte';
   GRANT SELECT, INSERT, UPDATE ON database.* TO 'app'@'190.57.138.18';
   ```

2. **Limitar en MySQL (no en firewall)**
   ```ini
   # /etc/mysql/mysql.conf.d/mysqld.cnf
   max_connections = 200
   max_user_connections = 50
   ```

3. **Monitorear Conexiones**
   ```bash
   # Ver conexiones en tiempo real
   watch -n 1 'sudo ss -tn | grep :3306 | wc -l'
   ```

## 🔧 Configuración Avanzada

### Si Necesitas Diferentes Límites

```bash
# Permitir hasta 100 conexiones desde tu IP (en lugar de ilimitado)
sudo iptables-legacy -I ANTIDDOS 1 -s 190.57.138.18 -p tcp --dport 3306 -m connlimit --connlimit-above 100 -j REJECT
sudo iptables-legacy -I ANTIDDOS 1 -s 190.57.138.18 -p tcp --dport 3306 -j ACCEPT
```

### Si Tienes Múltiples IPs Compartidas

```bash
# Crear archivo con IPs compartidas
cat > /tmp/shared_ips.txt << EOF
190.57.138.18
192.168.1.1
10.0.0.1
EOF

# Aplicar reglas a todas
while read ip; do
    sudo iptables-legacy -I ANTIDDOS 1 -s "$ip" -p tcp --dport 3306 -j ACCEPT
    echo "$ip  # IP compartida" | sudo tee -a /etc/antiddos/whitelist.txt
done < /tmp/shared_ips.txt

sudo netfilter-persistent save
```

## 🚨 Solución de Problemas

### Aún No Puedo Conectar

1. **Verificar que MySQL escucha en la IP correcta**
   ```bash
   sudo netstat -tlnp | grep 3306
   # Debe mostrar: 0.0.0.0:3306 o 190.57.138.18:3306
   ```

2. **Verificar bind-address en MySQL**
   ```bash
   sudo grep bind-address /etc/mysql/mysql.conf.d/mysqld.cnf
   # Debe ser: bind-address = 0.0.0.0
   ```

3. **Verificar usuario MySQL**
   ```sql
   SELECT user, host FROM mysql.user WHERE user = 'tu_usuario';
   -- Host debe ser '%' o '190.57.138.18'
   ```

4. **Ver logs de MySQL**
   ```bash
   sudo tail -f /var/log/mysql/error.log
   ```

### Regla No Funciona

```bash
# Ver orden de reglas
sudo iptables-legacy -L ANTIDDOS -n -v --line-numbers

# La regla de ACCEPT debe estar ANTES de REJECT
# Si no está en posición #1, moverla:
sudo iptables-legacy -D ANTIDDOS [numero_regla]
sudo iptables-legacy -I ANTIDDOS 1 -s 190.57.138.18 -p tcp --dport 3306 -j ACCEPT
sudo netfilter-persistent save
```

### Demasiadas Conexiones en MySQL

```bash
# Ver conexiones por usuario
mysql -u root -p -e "SELECT user, host, COUNT(*) as connections FROM information_schema.processlist GROUP BY user, host;"

# Matar conexiones inactivas
mysql -u root -p -e "CALL mysql.rds_kill_query(process_id);"
```

## 📋 Checklist

Después de aplicar la solución:

- [ ] Script ejecutado sin errores
- [ ] Regla visible en iptables
- [ ] IP agregada a whitelist
- [ ] Conexión MySQL exitosa desde servidores
- [ ] Sin errores en logs de MySQL
- [ ] Múltiples servidores pueden conectar simultáneamente
- [ ] Reglas guardadas con netfilter-persistent

## 📞 Comandos de Diagnóstico

```bash
# Ver todas las reglas de MySQL
sudo iptables-legacy -L ANTIDDOS -n -v | grep 3306

# Ver conexiones activas
sudo ss -tnp | grep :3306

# Ver intentos bloqueados (si los hay)
sudo journalctl -u antiddos-monitor | grep "190.57.138.18"

# Ver estadísticas de la regla
sudo iptables-legacy -L ANTIDDOS -n -v --line-numbers | grep "190.57.138.18"
```

## 🎯 Resumen

**Problema:** Límites de firewall bloqueaban múltiples servidores con IP compartida

**Solución:** Regla de prioridad máxima permite acceso ilimitado desde IP compartida

**Resultado:** Todos los servidores pueden conectarse sin límites de firewall

---

**Nota:** Esta configuración es específica para tu caso donde múltiples servidores internos comparten una IP pública. Para IPs externas desconocidas, los límites siguen aplicando.
