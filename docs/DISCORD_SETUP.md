# Configuración de Notificaciones Discord

## 📱 Guía Completa de Configuración

Esta guía te ayudará a configurar las notificaciones de Discord para recibir alertas automáticas sobre ataques DDoS, IPs bloqueadas y mitigaciones.

## 🎯 Características de las Notificaciones

### Notificaciones Automáticas

1. **Ataques DDoS Detectados**
   - Nivel de severidad (Moderado, Alto, Crítico)
   - Tráfico en Mbps y PPS
   - IPs principales atacantes
   - Timestamp del ataque

2. **Mitigaciones Activadas/Desactivadas**
   - Razón de activación
   - Acciones tomadas
   - Duración del ataque

3. **IPs Bloqueadas**
   - IP bloqueada
   - Razón del bloqueo
   - Duración del ban
   - Bloqueos masivos (cuando se bloquean múltiples IPs)

4. **Ataques SSH**
   - IP atacante
   - Número de intentos fallidos
   - Acción tomada

5. **Países Bloqueados**
   - Código del país
   - Número de rangos de IP bloqueados

## 📋 Paso 1: Crear Webhooks en Discord

### Crear un Webhook

1. **Abre tu servidor de Discord**
2. **Ve a Configuración del Servidor** → **Integraciones** → **Webhooks**
3. **Haz clic en "Nuevo Webhook"**
4. **Configura el webhook:**
   - Nombre: `Anti-DDoS Alerts` (o el nombre que prefieras)
   - Canal: Selecciona el canal donde quieres recibir notificaciones
5. **Copia la URL del Webhook**

### Tipos de Canales Recomendados

#### Canal Público (Opcional)
- **Propósito**: Notificar a la comunidad sobre ataques mayores
- **Nombre sugerido**: `#status` o `#server-status`
- **Recibe**: Solo ataques críticos y bloqueos masivos

#### Canal de Administración (Recomendado)
- **Propósito**: Todas las notificaciones detalladas
- **Nombre sugerido**: `#admin-alerts` o `#ddos-alerts`
- **Recibe**: Todas las notificaciones del sistema

## 📝 Paso 2: Configurar el Sistema

### Editar el Archivo de Configuración

```bash
sudo nano /etc/antiddos/config.yaml
```

### Configuración Básica (Un Solo Canal)

```yaml
notifications:
  enabled: true
  
  discord:
    enabled: true
    # Webhook principal
    webhook_url: "https://discord.com/api/webhooks/1234567890/AbCdEfGhIjKlMnOpQrStUvWxYz"
    
    # Configuración de notificaciones
    notify_attacks: true
    notify_mitigations: true
    notify_blocks: true
    notify_unblocks: false
```

### Configuración Avanzada (Múltiples Canales)

```yaml
notifications:
  enabled: true
  
  discord:
    enabled: true
    
    # Canal público para ataques mayores
    public_channel: "https://discord.com/api/webhooks/PUBLIC_ID/PUBLIC_TOKEN"
    
    # Canal de administración para todas las alertas
    admin_channel: "https://discord.com/api/webhooks/ADMIN_ID/ADMIN_TOKEN"
    
    # Mencionar rol en ataques críticos (opcional)
    mention_role: "987654321098765432"  # ID del rol a mencionar
    
    # Configuración de notificaciones
    notify_attacks: true
    notify_mitigations: true
    notify_blocks: true
    notify_unblocks: false
    
    # Umbrales para notificaciones públicas
    public_threshold_mbps: 500    # Notificar público si ataque > 500 Mbps
    public_threshold_ips: 10      # Notificar público si se bloquean > 10 IPs
```

## 🔑 Paso 3: Obtener ID de Rol (Opcional)

Para mencionar un rol en ataques críticos:

1. **Habilita el Modo Desarrollador en Discord:**
   - Configuración de Usuario → Avanzado → Modo Desarrollador

2. **Obtén el ID del Rol:**
   - Configuración del Servidor → Roles
   - Clic derecho en el rol → Copiar ID

3. **Agrega el ID a la configuración:**
   ```yaml
   mention_role: "123456789012345678"
   ```

## ✅ Paso 4: Probar la Configuración

### Probar Notificaciones

```bash
sudo antiddos-cli discord test
```

Deberías ver:
```
Testing Discord notifications...
✓ Discord notification sent successfully!
Check your Discord channel for the test message.
```

### Verificar en Discord

Busca un mensaje como este en tu canal:

```
✅ Prueba de Notificación
El sistema de notificaciones Discord está funcionando correctamente.

🕐 Hora: 2024-11-09 19:45:30
Sistema Anti-DDoS
```

## 🎨 Ejemplos de Notificaciones

### Ataque DDoS Detectado

```
🚨 CRÍTICO - Ataque DDoS Detectado
Se ha detectado un ataque DDoS en el servidor.

📊 Tráfico: 1250.50 Mbps
           125,000 PPS

🕐 Hora: 2024-11-09 19:45:30

🛡️ Estado: Mitigación activada automáticamente

🎯 IPs Principales:
1.2.3.4
5.6.7.8
9.10.11.12
```

### IP Bloqueada

```
🚫 IP Bloqueada Automáticamente
Se ha bloqueado una IP maliciosa.

🎯 IP: 1.2.3.4
⏱️ Duración: 1 horas
📝 Razón: Exceso de conexiones (150 conn/s)
🕐 Hora: 2024-11-09 19:45:30
```

### Ataque SSH

```
🔐 Ataque SSH Detectado
Se ha detectado un ataque de fuerza bruta SSH.

🎯 IP Atacante: 1.2.3.4
🔢 Intentos: 15
🛡️ Acción: IP bloqueada automáticamente
🕐 Hora: 2024-11-09 19:45:30
```

## ⚙️ Configuración Avanzada

### Personalizar Umbrales

```yaml
discord:
  # Solo notificar ataques mayores a 1 Gbps al público
  public_threshold_mbps: 1000
  
  # Solo notificar bloqueos masivos (>20 IPs) al público
  public_threshold_ips: 20
```

### Desactivar Notificaciones Específicas

```yaml
discord:
  notify_attacks: true          # Mantener
  notify_mitigations: true      # Mantener
  notify_blocks: true           # Mantener
  notify_unblocks: false        # Desactivar (puede ser ruidoso)
```

### Reportes Diarios (Próximamente)

```yaml
discord:
  send_daily_report: true
  report_time: "09:00"  # Enviar reporte a las 9 AM
```

## 🔧 Solución de Problemas

### No se envían notificaciones

1. **Verificar que Discord esté habilitado:**
   ```bash
   grep -A 5 "discord:" /etc/antiddos/config.yaml
   ```

2. **Verificar URL del webhook:**
   - Debe comenzar con `https://discord.com/api/webhooks/`
   - No debe contener `YOUR_WEBHOOK`

3. **Probar manualmente:**
   ```bash
   curl -X POST "TU_WEBHOOK_URL" \
     -H "Content-Type: application/json" \
     -d '{"content": "Test message"}'
   ```

4. **Verificar logs:**
   ```bash
   sudo grep -i "discord" /var/log/antiddos/antiddos.log
   ```

### Webhook inválido

```
Error: Discord webhook failed: 404
```

**Solución**: El webhook fue eliminado o la URL es incorrecta. Crea un nuevo webhook.

### Demasiadas notificaciones

**Solución**: Ajusta los umbrales o desactiva notificaciones específicas:

```yaml
discord:
  notify_unblocks: false  # Desactivar notificaciones de desbloqueo
  public_threshold_ips: 20  # Aumentar umbral
```

### Rate Limiting

Discord limita webhooks a:
- 30 mensajes por minuto
- 5 mensajes por segundo

El sistema maneja esto automáticamente, pero en ataques masivos algunas notificaciones pueden retrasarse.

## 📊 Mejores Prácticas

### 1. Usar Múltiples Canales

```
#server-status (Público)
  ↓ Solo ataques críticos
  
#admin-alerts (Privado)
  ↓ Todas las notificaciones
  
#ddos-logs (Archivo)
  ↓ Log completo
```

### 2. Configurar Roles

Crea roles específicos:
- `@DDoS-Team` - Equipo de respuesta
- `@Admins` - Administradores
- `@Moderators` - Moderadores

### 3. Establecer Procedimientos

Documenta qué hacer cuando recibes cada tipo de alerta:

**Ataque Crítico (>1 Gbps)**
1. Verificar servicios
2. Revisar logs
3. Contactar proveedor si es necesario

**Bloqueo Masivo (>10 IPs)**
1. Verificar falsos positivos
2. Revisar whitelist
3. Ajustar umbrales si es necesario

### 4. Monitorear Regularmente

- Revisa notificaciones diarias
- Ajusta umbrales según patrones
- Mantén whitelist actualizada

## 🔐 Seguridad

### Proteger Webhooks

1. **No compartas URLs de webhook públicamente**
2. **Regenera webhooks si se comprometen**
3. **Usa canales privados para notificaciones sensibles**
4. **Limita permisos del webhook**

### Permisos Recomendados del Canal

```
Ver Canal: ✓
Enviar Mensajes: ✓ (Solo webhook)
Insertar Enlaces: ✓
Adjuntar Archivos: ✗
Mencionar @everyone: ✗
```

## 📱 Notificaciones Móviles

Para recibir notificaciones en tu teléfono:

1. **Instala Discord en tu móvil**
2. **Activa notificaciones push para el canal**
3. **Configura menciones de rol** para ataques críticos

## 🎯 Ejemplos de Uso

### Servidor de Juegos

```yaml
discord:
  public_channel: "..."  # Canal público del servidor
  admin_channel: "..."   # Canal de staff
  public_threshold_mbps: 300  # Notificar a jugadores si >300 Mbps
  notify_unblocks: false  # No molestar con desbloqueos
```

### Servidor de Producción

```yaml
discord:
  admin_channel: "..."  # Solo canal de admins
  mention_role: "..."   # Mencionar @oncall
  public_threshold_mbps: 1000  # Umbral alto
  notify_blocks: true   # Notificar todos los bloqueos
```

### Servidor de Desarrollo

```yaml
discord:
  webhook_url: "..."  # Un solo canal
  notify_attacks: true
  notify_mitigations: false  # No notificar mitigaciones menores
  notify_blocks: false  # No notificar bloqueos individuales
```

## 📚 Recursos Adicionales

- [Discord Webhook Documentation](https://discord.com/developers/docs/resources/webhook)
- [Discord Rate Limits](https://discord.com/developers/docs/topics/rate-limits)
- [Markdown en Discord](https://support.discord.com/hc/en-us/articles/210298617)

## 🆘 Soporte

Si tienes problemas:

1. Revisa los logs: `sudo journalctl -u antiddos-monitor -f`
2. Prueba el webhook: `sudo antiddos-cli discord test`
3. Verifica la configuración: `cat /etc/antiddos/config.yaml | grep -A 20 discord`

---

**¡Tu sistema ahora enviará notificaciones automáticas a Discord!** 🎉
