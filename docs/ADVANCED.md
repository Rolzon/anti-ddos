# Advanced Configuration Guide

## Custom Firewall Rules

### Adding Custom Rules

You can add custom iptables rules to the ANTIDDOS chain:

```bash
# Block specific port
sudo iptables -I ANTIDDOS -p tcp --dport 8080 -j DROP

# Rate limit HTTP traffic
sudo iptables -I ANTIDDOS -p tcp --dport 80 -m limit --limit 100/s -j ACCEPT
sudo iptables -I ANTIDDOS -p tcp --dport 80 -j DROP

# Block specific subnet
sudo iptables -I ANTIDDOS -s 192.168.1.0/24 -j DROP
```

### Persistent Custom Rules

Create a script in `/etc/antiddos/custom-rules.sh`:

```bash
#!/bin/bash
# Custom firewall rules

# Add your custom rules here
iptables -I ANTIDDOS -p tcp --dport 3306 -m connlimit --connlimit-above 10 -j REJECT
iptables -I ANTIDDOS -p tcp --dport 5432 -m connlimit --connlimit-above 10 -j REJECT
```

Make it executable and add to systemd service:

```bash
sudo chmod +x /etc/antiddos/custom-rules.sh
```

Edit `/etc/systemd/system/antiddos-monitor.service`:

```ini
[Service]
ExecStartPost=/etc/antiddos/custom-rules.sh
```

## Multi-Server Setup with XCord

### Server 1 Configuration

`/etc/antiddos/config.yaml`:

```yaml
xcord:
  enabled: true
  port: 9999
  encryption_key: "shared_secret_key_32_chars_minimum"
  auth_token: "shared_auth_token"
  peers:
    - "server2.example.com:9999"
    - "server3.example.com:9999"
```

### Server 2 & 3 Configuration

Same configuration but with different peer lists:

```yaml
xcord:
  enabled: true
  port: 9999
  encryption_key: "shared_secret_key_32_chars_minimum"  # MUST be the same
  auth_token: "shared_auth_token"  # MUST be the same
  peers:
    - "server1.example.com:9999"
    - "server3.example.com:9999"  # (or server2 for server3)
```

### Firewall Configuration for XCord

Allow XCord port between servers:

```bash
# On each server, allow XCord port from other servers
sudo iptables -I INPUT -p tcp --dport 9999 -s SERVER_IP -j ACCEPT
```

## Advanced Bandwidth Monitoring

### Per-Interface Monitoring

Monitor multiple interfaces:

```yaml
# Create separate config files for each interface
bandwidth:
  interface: eth0
  threshold_mbps: 1000
```

Run multiple monitor instances:

```bash
sudo systemctl start antiddos-monitor@eth0
sudo systemctl start antiddos-monitor@eth1
```

### Custom Thresholds by Time

Create a cron job to adjust thresholds:

```bash
# /etc/cron.d/antiddos-schedule
# Higher limits during business hours
0 9 * * 1-5 root sed -i 's/threshold_mbps: .*/threshold_mbps: 2000/' /etc/antiddos/config.yaml && systemctl reload antiddos-monitor

# Lower limits at night
0 18 * * * root sed -i 's/threshold_mbps: .*/threshold_mbps: 1000/' /etc/antiddos/config.yaml && systemctl reload antiddos-monitor
```

## GeoIP Database Management

### Manual Database Installation

1. Download from MaxMind:
   ```bash
   wget "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=YOUR_KEY&suffix=tar.gz" -O GeoLite2-Country.tar.gz
   ```

2. Extract:
   ```bash
   tar -xzf GeoLite2-Country.tar.gz
   sudo cp GeoLite2-Country_*/GeoLite2-Country.mmdb /usr/share/GeoIP/
   ```

3. Set up automatic updates:
   ```bash
   # /etc/cron.weekly/update-geoip
   #!/bin/bash
   cd /tmp
   wget -q "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=YOUR_KEY&suffix=tar.gz" -O GeoLite2-Country.tar.gz
   tar -xzf GeoLite2-Country.tar.gz
   cp GeoLite2-Country_*/GeoLite2-Country.mmdb /usr/share/GeoIP/
   systemctl restart antiddos-monitor
   ```

## SSH Protection Advanced Features

### Custom Regex Patterns

Edit `src/antiddos/ssh_protection.py` to add custom patterns:

```python
self.patterns = [
    # Add custom patterns
    re.compile(r'authentication failure.*rhost=(\d+\.\d+\.\d+\.\d+)'),
    re.compile(r'Failed publickey for .+ from (\d+\.\d+\.\d+\.\d+)'),
]
```

### Integration with Existing Fail2ban

If you have Fail2ban installed, you can integrate:

```bash
# Disable SSH protection in Anti-DDoS
sudo systemctl stop antiddos-ssh
sudo systemctl disable antiddos-ssh

# Configure Fail2ban to use Anti-DDoS blacklist
# /etc/fail2ban/action.d/antiddos.conf
[Definition]
actionban = /usr/local/bin/antiddos-cli blacklist add <ip>
actionunban = /usr/local/bin/antiddos-cli blacklist remove <ip>
```

## Performance Tuning

### High-Traffic Servers

For servers handling >10Gbps:

```yaml
bandwidth:
  threshold_mbps: 10000
  threshold_pps: 1000000
  window_seconds: 5  # Faster response

dos_filter:
  syn_flood:
    threshold: 200
  udp_flood:
    threshold: 500
  connection_limit:
    max_connections: 200

advanced:
  max_conntrack_entries: 500000
```

### Low-Resource Servers

For VPS with limited resources:

```yaml
general:
  check_interval: 10  # Check less frequently

bandwidth:
  window_seconds: 30  # Longer averaging window

advanced:
  max_conntrack_entries: 50000
```

## Monitoring and Alerting

### Prometheus Integration

Create a metrics exporter:

```python
# /usr/local/bin/antiddos-exporter
from prometheus_client import start_http_server, Gauge
import time
from antiddos.blacklist import BlacklistManager
from antiddos.config import Config

config = Config()
blacklist_mgr = BlacklistManager(config)

# Metrics
blacklist_size = Gauge('antiddos_blacklist_size', 'Number of blacklisted IPs')
whitelist_size = Gauge('antiddos_whitelist_size', 'Number of whitelisted IPs')

def collect_metrics():
    blacklist_mgr.load()
    blacklist_size.set(len(blacklist_mgr.get_blacklist()))
    whitelist_size.set(len(blacklist_mgr.get_whitelist()))

if __name__ == '__main__':
    start_http_server(9100)
    while True:
        collect_metrics()
        time.sleep(60)
```

### Email Notifications

Configure in `config.yaml`:

```yaml
notifications:
  enabled: true
  email:
    enabled: true
    smtp_server: smtp.gmail.com
    smtp_port: 587
    from_address: antiddos@yourdomain.com
    to_addresses:
      - admin@yourdomain.com
    username: your_email@gmail.com
    password: your_app_password
```

### Webhook Notifications (Slack/Discord)

```yaml
notifications:
  enabled: true
  webhook:
    enabled: true
    url: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

## Database Protection Strategies

### MySQL/MariaDB

```bash
# Limit connections per IP
sudo iptables -I ANTIDDOS -p tcp --dport 3306 -m connlimit --connlimit-above 10 -j REJECT

# Rate limit new connections
sudo iptables -I ANTIDDOS -p tcp --dport 3306 --syn -m limit --limit 10/s -j ACCEPT
sudo iptables -I ANTIDDOS -p tcp --dport 3306 --syn -j DROP

# Only allow from specific IPs
sudo iptables -I ANTIDDOS -p tcp --dport 3306 ! -s 192.168.1.0/24 -j DROP
```

### PostgreSQL

```bash
# Similar rules for PostgreSQL
sudo iptables -I ANTIDDOS -p tcp --dport 5432 -m connlimit --connlimit-above 10 -j REJECT
sudo iptables -I ANTIDDOS -p tcp --dport 5432 --syn -m limit --limit 10/s -j ACCEPT
sudo iptables -I ANTIDDOS -p tcp --dport 5432 --syn -j DROP
```

### Redis

```bash
# Protect Redis
sudo iptables -I ANTIDDOS -p tcp --dport 6379 -m connlimit --connlimit-above 20 -j REJECT
```

## Pterodactyl-Specific Protection

### Panel Protection

```bash
# Rate limit HTTP/HTTPS
sudo iptables -I ANTIDDOS -p tcp --dport 80 -m limit --limit 100/s --limit-burst 200 -j ACCEPT
sudo iptables -I ANTIDDOS -p tcp --dport 443 -m limit --limit 100/s --limit-burst 200 -j ACCEPT

# Connection limits
sudo iptables -I ANTIDDOS -p tcp --dport 80 -m connlimit --connlimit-above 50 -j REJECT
sudo iptables -I ANTIDDOS -p tcp --dport 443 -m connlimit --connlimit-above 50 -j REJECT
```

### Wings (Daemon) Protection

```bash
# Protect Wings API port (default 8080)
sudo iptables -I ANTIDDOS -p tcp --dport 8080 -m connlimit --connlimit-above 30 -j REJECT

# Whitelist panel IP
sudo antiddos-cli whitelist add PANEL_IP
```

### Game Server Protection

```bash
# Protect game server ports (example: Minecraft)
sudo iptables -I ANTIDDOS -p tcp --dport 25565 -m limit --limit 50/s -j ACCEPT
sudo iptables -I ANTIDDOS -p udp --dport 25565 -m limit --limit 100/s -j ACCEPT
```

## Logging and Debugging

### Enable Debug Logging

```yaml
general:
  log_level: DEBUG
```

### Separate Log Files

```yaml
general:
  log_file: /var/log/antiddos/antiddos.log
  
# Add to systemd service
[Service]
StandardOutput=append:/var/log/antiddos/monitor.log
StandardError=append:/var/log/antiddos/monitor-error.log
```

### Log Rotation

Create `/etc/logrotate.d/antiddos`:

```
/var/log/antiddos/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
    postrotate
        systemctl reload antiddos-monitor
    endscript
}
```

## Backup and Recovery

### Backup Script

```bash
#!/bin/bash
# /usr/local/bin/backup-antiddos

BACKUP_DIR="/backup/antiddos"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Backup configuration
tar -czf "$BACKUP_DIR/antiddos-config-$DATE.tar.gz" \
    /etc/antiddos/

# Backup firewall rules
iptables-save > "$BACKUP_DIR/iptables-$DATE.rules"

# Keep only last 7 backups
find "$BACKUP_DIR" -name "antiddos-config-*.tar.gz" -mtime +7 -delete
find "$BACKUP_DIR" -name "iptables-*.rules" -mtime +7 -delete
```

### Restore Script

```bash
#!/bin/bash
# /usr/local/bin/restore-antiddos

if [ -z "$1" ]; then
    echo "Usage: $0 <backup-file>"
    exit 1
fi

# Stop services
systemctl stop antiddos-monitor antiddos-ssh antiddos-xcord

# Restore configuration
tar -xzf "$1" -C /

# Restart services
systemctl start antiddos-monitor antiddos-ssh antiddos-xcord
```

## Security Hardening

### Secure Configuration File

```bash
sudo chmod 600 /etc/antiddos/config.yaml
sudo chown root:root /etc/antiddos/config.yaml
```

### SELinux/AppArmor

For systems with SELinux or AppArmor, you may need to create policies.

### Audit Logging

Enable audit logging for all Anti-DDoS actions:

```yaml
general:
  audit_log: /var/log/antiddos/audit.log
```

## Troubleshooting

### High CPU Usage

1. Increase check interval
2. Reduce logging verbosity
3. Optimize firewall rules

### Memory Issues

1. Reduce max_conntrack_entries
2. Implement log rotation
3. Clear old blacklist entries

### Network Performance Impact

1. Use hardware firewall if available
2. Optimize iptables rules order
3. Consider using nftables instead of iptables

## Migration from Other Solutions

### From Fail2ban

1. Export Fail2ban bans:
   ```bash
   fail2ban-client status sshd | grep "Banned IP" | awk '{print $NF}' > banned_ips.txt
   ```

2. Import to Anti-DDoS:
   ```bash
   while read ip; do
       antiddos-cli blacklist add "$ip"
   done < banned_ips.txt
   ```

### From CSF (ConfigServer Firewall)

1. Export CSF deny list:
   ```bash
   cat /etc/csf/csf.deny | awk '{print $1}' > csf_denied.txt
   ```

2. Import to Anti-DDoS:
   ```bash
   while read ip; do
       antiddos-cli blacklist add "$ip"
   done < csf_denied.txt
   ```
