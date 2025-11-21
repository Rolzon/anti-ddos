# Fix: Cleanup en Sistemas nftables

## 🔴 Problema

Al detener el servicio y verificar el cleanup:

```bash
sudo systemctl stop antiddos-monitor
sudo iptables -L ANTIDDOS -n
```

**Error obtenido:**
```
iptables v1.8.7 (nf_tables): chain `ANTIDDOS' in table `filter' is incompatible, use 'nft' tool.
```

**Significado:** La cadena ANTIDDOS todavía existe (cleanup no funcionó) y el sistema usa nftables backend.

## 🔍 Causa

Tu sistema usa **iptables con backend nftables** (iptables-nft). Cuando ejecutas `iptables` sin el sufijo `-nft`, puede no funcionar correctamente o no mostrar las reglas.

## ✅ Solución Inmediata (Limpieza Manual)

### Opción 1: Usar nft directamente (Recomendado)

```bash
# Ver las cadenas ANTIDDOS
sudo nft list table ip filter | grep "chain ANTIDDOS"

# Si existen, eliminarlas manualmente:
# Primero, eliminar las referencias
sudo nft list table ip filter -a | grep "jump ANTIDDOS"

# Luego flush y delete cada cadena
sudo nft flush chain ip filter ANTIDDOS
sudo nft delete chain ip filter ANTIDDOS

# Repetir para otras cadenas ANTIDDOS_* si existen
```

### Opción 2: Script Automático

```bash
cd /opt/anti-ddos
sudo chmod +x scripts/manual-cleanup-nftables.sh
sudo bash scripts/manual-cleanup-nftables.sh
```

Este script:
- ✅ Detecta automáticamente si usar nft o iptables-nft
- ✅ Elimina todas las cadenas ANTIDDOS
- ✅ Elimina todas las referencias (saltos)
- ✅ Verifica que la limpieza fue exitosa

### Opción 3: Usar iptables-nft

```bash
# Verificar que iptables-nft existe
which iptables-nft

# Eliminar saltos
sudo iptables-nft -D INPUT -j ANTIDDOS
sudo iptables-nft -D FORWARD -j ANTIDDOS

# Eliminar cadenas
sudo iptables-nft -F ANTIDDOS
sudo iptables-nft -X ANTIDDOS
```

## 🔧 Fix Permanente (Actualizar Código)

El código ya está actualizado para usar `iptables-nft` automáticamente, pero necesitas:

### 1. Verificar el binario detectado

```bash
# Ver qué comando está usando el sistema
sudo journalctl -u antiddos-monitor | grep "Using iptables"
```

Debería mostrar:
```
Using iptables binary: iptables-nft
```

### 2. Si no detecta iptables-nft

Verifica que está instalado:

```bash
# En Debian/Ubuntu
sudo apt-get install iptables

# Verificar
iptables-nft --version
```

### 3. Actualizar el código

El código mejorado en `firewall.py` ahora:
- ✅ Detecta `iptables-nft` primero
- ✅ Usa `-S` en lugar de `-L` para mejor parsing
- ✅ Elimina todas las referencias antes de borrar cadenas
- ✅ Log detallado del proceso de cleanup
- ✅ Retorna estado de éxito/fallo

### 4. Reinstalar

```bash
cd /opt/anti-ddos
sudo pip3 install -e . --force-reinstall
```

## 📋 Verificación Post-Fix

### Test 1: Verificar que detecta nftables

```bash
sudo systemctl start antiddos-monitor
sudo journalctl -u antiddos-monitor -n 20

# Buscar línea:
# "Using iptables binary: iptables-nft"
```

### Test 2: Verificar cleanup funciona

```bash
# Detener servicio
sudo systemctl stop antiddos-monitor

# Esperar 2 segundos
sleep 2

# Verificar con script
sudo bash scripts/verify-cleanup.sh
```

**Resultado esperado:**
```
✓ PASS: Cadena ANTIDDOS no existe (limpiado correctamente)
```

### Test 3: Verificar con nft

```bash
# Ver todas las cadenas
sudo nft list table ip filter

# No debe aparecer ANTIDDOS
```

### Test 4: Verificar con iptables-nft

```bash
# Intentar listar la cadena
sudo iptables-nft -L ANTIDDOS -n

# Debe dar error: "No chain/target/match by that name"
```

## 🐛 Debugging

### Ver estado actual del firewall

```bash
# Con nft (más claro)
sudo nft list ruleset | grep -A 10 ANTIDDOS

# Con iptables-nft
sudo iptables-nft -S | grep ANTIDDOS
```

### Ver logs del cleanup

```bash
# Logs del servicio al detenerse
sudo journalctl -u antiddos-monitor | grep -i "cleanup"

# Debe mostrar:
# "Cleaning up firewall rules using iptables-nft"
# "Removed X jump(s) from INPUT chain"
# "Flushed chain ANTIDDOS"
# "Deleted chain ANTIDDOS"
# "✓ Cleanup completed successfully"
```

### Si el cleanup sigue fallando

```bash
# Ver error exacto
sudo journalctl -u antiddos-monitor -n 50 | grep -i "error\|failed\|warning"

# Ver comando exacto que está usando
sudo journalctl -u antiddos-monitor | grep "Using iptables binary"
```

## 📊 Comparación de Comandos

| Acción | iptables (legacy) | iptables-nft | nft |
|--------|------------------|--------------|-----|
| Listar cadenas | `iptables -L` | `iptables-nft -L` | `nft list table ip filter` |
| Listar reglas | `iptables -S` | `iptables-nft -S` | `nft list ruleset` |
| Eliminar regla | `iptables -D` | `iptables-nft -D` | `nft delete rule` |
| Flush cadena | `iptables -F` | `iptables-nft -F` | `nft flush chain` |
| Borrar cadena | `iptables -X` | `iptables-nft -X` | `nft delete chain` |

## ⚠️ Importante

### NO usar iptables-legacy

Si tu sistema tiene tanto `iptables-legacy` como `iptables-nft`, **SIEMPRE usa iptables-nft**:

```bash
# MAL - No funciona con Docker
sudo iptables-legacy -L

# BIEN - Compatible con Docker/nftables
sudo iptables-nft -L

# MEJOR - Nativo
sudo nft list ruleset
```

### Por qué nftables

Docker y Pterodactyl Wings usan **nftables backend**. Si usas iptables-legacy, las reglas estarán en tablas separadas y no funcionará correctamente.

## 🔄 Migración Completa a nftables

Si quieres usar nft directamente (opcional):

```bash
# 1. Ver reglas actuales
sudo iptables-nft-save > /tmp/current-rules.txt

# 2. Instalar nftables
sudo apt-get install nftables

# 3. Convertir reglas (si necesario)
sudo iptables-nft-save | sudo nft -f -

# 4. Habilitar nftables
sudo systemctl enable nftables
sudo systemctl start nftables
```

**NOTA:** No es necesario migrar completamente. El sistema Anti-DDoS funciona perfectamente con `iptables-nft`.

## 📝 Resumen

### Problema detectado
- ✅ La cadena ANTIDDOS sigue existiendo después de `systemctl stop`
- ✅ El sistema usa nftables backend
- ✅ El comando `iptables` sin `-nft` no funciona correctamente

### Solución aplicada
- ✅ Script de limpieza manual para nftables: `manual-cleanup-nftables.sh`
- ✅ Script de verificación: `verify-cleanup.sh`
- ✅ Código mejorado para detectar y usar `iptables-nft` automáticamente
- ✅ Cleanup mejorado con mejor logging y verificación

### Pasos a seguir
1. **Ejecutar limpieza manual ahora:**
   ```bash
   sudo bash scripts/manual-cleanup-nftables.sh
   ```

2. **Actualizar código:**
   ```bash
   cd /opt/anti-ddos
   sudo pip3 install -e . --force-reinstall
   ```

3. **Verificar que funciona:**
   ```bash
   sudo systemctl start antiddos-monitor
   sudo systemctl stop antiddos-monitor
   sudo bash scripts/verify-cleanup.sh
   ```

---

**Última actualización**: 2024-11-21  
**Estado**: CRÍTICO - Aplica inmediatamente si ves el error de nftables
