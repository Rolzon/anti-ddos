# 🚀 INSTRUCCIONES PARA ACTUALIZAR EN TU SERVIDOR

## 📍 Ubicación del Proyecto

Según tu instalación, el proyecto debería estar en:
```
/opt/anti-ddos
```

## ⚡ Actualización Rápida (Recomendada)

Conéctate a tu servidor y ejecuta:

```bash
# 1. Ir al directorio del proyecto
cd /opt/anti-ddos

# 2. Ejecutar actualización completa
sudo bash update-to-v1.0.1.sh
```

**Eso es todo!** El script hará:
- ✅ Backup automático de tu configuración
- ✅ Actualización del código desde GitHub
- ✅ Preservación de whitelist/blacklist
- ✅ Reinicio de servicios
- ✅ Verificación de protecciones

---

## 🔄 Opción Alternativa: Actualización Manual

Si prefieres hacerlo paso a paso:

```bash
# 1. Conectar al servidor
ssh root@190.57.138.18

# 2. Ir al directorio
cd /opt/anti-ddos

# 3. Verificar versión actual
cat VERSION
# Debe mostrar: 1.0.0

# 4. Hacer backup de configuración
mkdir -p /tmp/antiddos-backup
cp -r /etc/antiddos/* /tmp/antiddos-backup/

# 5. Detener servicios
systemctl stop antiddos-monitor
systemctl stop antiddos-ssh
systemctl stop antiddos-xcord

# 6. Actualizar código desde GitHub
git fetch origin
git reset --hard origin/main

# 7. Actualizar paquete Python
pip3 install -e . --upgrade

# 8. Restaurar configuración
cp /tmp/antiddos-backup/* /etc/antiddos/

# 9. Reiniciar servicios
systemctl daemon-reload
systemctl start antiddos-monitor
systemctl start antiddos-ssh
systemctl start antiddos-xcord

# 10. Verificar versión nueva
cat VERSION
# Debe mostrar: 1.0.1

# 11. Verificar que todo funciona
systemctl status antiddos-monitor
```

---

## ✅ Verificación Post-Actualización

Después de actualizar, verifica que todo funciona:

```bash
# 1. Ver versión
cat /opt/anti-ddos/VERSION

# 2. Ver servicios
systemctl status antiddos-monitor

# 3. Ver logs
journalctl -u antiddos-monitor -n 50

# 4. Ejecutar test de protecciones
bash /opt/anti-ddos/scripts/test-protections.sh

# 5. Verificar Docker
systemctl status docker
iptables -t nat -L DOCKER -n

# 6. Verificar Wings
systemctl status wings

# 7. Verificar subnet protegida
iptables -L INPUT -n | grep 172.18.0
```

---

## 🎯 Lo Que Verás Después de Actualizar

### Nuevos Archivos

```
/opt/anti-ddos/
├── docs/FIREWALL_SAFETY.md          ← Guía de seguridad
├── GARANTIAS_DOCKER.md              ← Garantías técnicas
├── SECURITY_UPDATE.md               ← Detalles de actualización
├── UPDATE_GUIDE.md                  ← Guía completa
├── update-to-v1.0.1.sh             ← Script de actualización
├── quick-update.sh                  ← Actualización rápida
└── scripts/test-protections.sh      ← Test de protecciones
```

### Logs de Protección

Ahora verás logs como estos:

```bash
tail -f /var/log/antiddos/antiddos.log
```

```
[INFO] Using iptables binary: iptables-nft
[INFO] Docker exceptions added with full subnet protection
[INFO] Firewall rules initialized
```

Si alguien intenta algo peligroso:

```
[WARNING] BLOCKED: Attempted to modify protected chain: iptables -F DOCKER
[WARNING] BLOCKED: Dangerous operation prevented: iptables -t nat -F
```

---

## 🔍 Comandos Útiles Post-Actualización

```bash
# Ver todas las reglas
iptables -L -n -v --line-numbers

# Ver subnet protegida (debe aparecer 172.18.0.0/16)
iptables -L INPUT -n | grep 172.18

# Ver cadenas Docker (deben estar intactas)
iptables -t nat -L DOCKER -n

# Ver logs en tiempo real
journalctl -u antiddos-monitor -f

# Ver estadísticas
antiddos-cli stats

# Ver IPs bloqueadas
antiddos-cli blacklist list
```

---

## ⚠️ Importante

Durante la actualización (30 segundos - 2 minutos):

- ✅ Docker seguirá funcionando
- ✅ Wings seguirá funcionando  
- ✅ Tus servidores de Minecraft seguirán corriendo
- ⚠️ La protección Anti-DDoS estará temporalmente desactivada

---

## 🆘 Si Algo Sale Mal

### Restaurar Configuración

```bash
# Restaurar desde backup
cp /tmp/antiddos-backup/* /etc/antiddos/
systemctl restart antiddos-monitor
```

### Ver Errores

```bash
# Ver logs detallados
journalctl -u antiddos-monitor -n 100 --no-pager

# Ver errores específicos
journalctl -u antiddos-monitor | grep -i error
```

### Reinstalar Paquete

```bash
cd /opt/anti-ddos
pip3 install -e . --force-reinstall
systemctl restart antiddos-monitor
```

### Volver a Versión Anterior

```bash
cd /opt/anti-ddos
systemctl stop antiddos-monitor antiddos-ssh antiddos-xcord
git checkout v1.0.0
pip3 install -e . --force-reinstall
systemctl start antiddos-monitor antiddos-ssh antiddos-xcord
```

---

## 📞 Contacto

Si necesitas ayuda durante la actualización, revisa:

1. **Logs**: `journalctl -u antiddos-monitor -n 100`
2. **Diagnóstico**: `bash /opt/anti-ddos/scripts/diagnose.sh`
3. **Test**: `bash /opt/anti-ddos/scripts/test-protections.sh`

---

## 🎉 Después de Actualizar

Una vez completada la actualización:

1. ✅ Tu configuración estará preservada
2. ✅ Docker/Pterodactyl estarán protegidos
3. ✅ La subnet 172.18.0.0/16 estará explícitamente protegida
4. ✅ Operaciones peligrosas estarán bloqueadas
5. ✅ Tendrás nueva documentación de seguridad

**Tu sistema estará más seguro y Docker/Wings nunca serán modificados accidentalmente.**

---

## 📋 Checklist de Actualización

- [ ] Conectar al servidor
- [ ] Ir a `/opt/anti-ddos`
- [ ] Ejecutar `sudo bash update-to-v1.0.1.sh`
- [ ] Esperar 2-3 minutos
- [ ] Verificar versión: `cat VERSION` → debe mostrar `1.0.1`
- [ ] Verificar servicios: `systemctl status antiddos-monitor`
- [ ] Ejecutar test: `bash scripts/test-protections.sh`
- [ ] Verificar Docker: `systemctl status docker`
- [ ] Verificar Wings: `systemctl status wings`
- [ ] Ver logs: `journalctl -u antiddos-monitor -n 50`

**¡Listo!** 🎉
