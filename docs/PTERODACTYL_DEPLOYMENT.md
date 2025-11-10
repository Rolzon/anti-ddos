# Pterodactyl & Database Server Deployment Guide

This guide is specifically for protecting servers running Pterodactyl Panel and databases.

## Pre-Installation Checklist

- [ ] Ubuntu 22.04 LTS installed
- [ ] Root or sudo access
- [ ] Pterodactyl Panel installed and working
- [ ] Database server (MySQL/PostgreSQL) installed
- [ ] Note your current IP address (to whitelist)
- [ ] Note all server IPs that need to communicate

## Installation Steps

### 1. Download and Install

```bash
# Clone the repository
cd /opt
git clone <your-repo-url> anti-ddos
cd anti-ddos

# Make scripts executable
chmod +x install.sh test_installation.sh

# Run installation
sudo ./install.sh

# Test installation
sudo ./test_installation.sh
```

### 2. Initial Configuration

#### A. Whitelist Your IPs (CRITICAL!)

```bash
# Your management IP
sudo antiddos-cli whitelist add YOUR_ADMIN_IP

# Pterodactyl Panel IP (if separate from database)
sudo antiddos-cli whitelist add PANEL_IP

# Wings/Daemon IPs
sudo antiddos-cli whitelist add WINGS_IP_1
sudo antiddos-cli whitelist add WINGS_IP_2

# Application server IPs
sudo antiddos-cli whitelist add APP_SERVER_IP
```

#### B. Configure Network Interface

Find your network interface:
```bash
ip a
```

Edit `/etc/antiddos/config.yaml`:
```yaml
bandwidth:
  interface: eth0  # Change to your interface (e.g., ens3, enp0s3)
  threshold_mbps: 1000  # Adjust based on your bandwidth
  threshold_pps: 100000
```

#### C. Configure Country Blocking

Edit `/etc/antiddos/config.yaml`:
```yaml
country_filter:
  enabled: true
  mode: blacklist
  blacklist:
    - CN  # China
    - RU  # Russia
    - KP  # North Korea
    - IR  # Iran
    # Add more as needed
  trigger_on_bandwidth: true
  trigger_threshold_mbps: 500  # Activate during high traffic
```

#### D. Configure SSH Protection

```yaml
ssh_protection:
  enabled: true
  max_attempts: 3  # Strict for production
  ban_time: 7200   # 2 hours
  find_time: 600   # 10 minutes
  banner: |
    ===============================================
    UNAUTHORIZED ACCESS DETECTED
    ===============================================
    This server is protected by Anti-DDoS system.
    Your IP has been logged and will be banned.
    All activities are monitored and recorded.
    ===============================================
```

#### E. Configure XCord (Multi-Server Setup)

If you have multiple servers (e.g., separate panel and database servers):

**Generate secure keys:**
```bash
# Encryption key (save this!)
openssl rand -base64 32

# Auth token (save this!)
openssl rand -hex 32
```

Edit `/etc/antiddos/config.yaml` on **ALL servers**:
```yaml
xcord:
  enabled: true
  port: 9999
  encryption_key: "YOUR_GENERATED_KEY_HERE"  # MUST be identical on all servers
  auth_token: "YOUR_GENERATED_TOKEN_HERE"    # MUST be identical on all servers
  peers:
    - "server2.example.com:9999"  # Other server IPs
    - "server3.example.com:9999"
  sync_interval: 300
```

**Open XCord port between servers:**
```bash
# On each server, allow XCord from other servers
sudo iptables -I INPUT -p tcp --dport 9999 -s OTHER_SERVER_IP -j ACCEPT
```

### 3. Database Protection

#### MySQL/MariaDB Protection

```bash
# Limit connections per IP to database port
sudo iptables -I ANTIDDOS -p tcp --dport 3306 -m connlimit --connlimit-above 10 -j REJECT

# Rate limit new connections
sudo iptables -I ANTIDDOS -p tcp --dport 3306 --syn -m limit --limit 10/s -j ACCEPT
sudo iptables -I ANTIDDOS -p tcp --dport 3306 --syn -j DROP

# Only allow from whitelisted IPs (if database is separate)
# This blocks all except whitelisted IPs
sudo iptables -I ANTIDDOS -p tcp --dport 3306 -m state --state NEW -j DROP
```

#### PostgreSQL Protection

```bash
# Same for PostgreSQL
sudo iptables -I ANTIDDOS -p tcp --dport 5432 -m connlimit --connlimit-above 10 -j REJECT
sudo iptables -I ANTIDDOS -p tcp --dport 5432 --syn -m limit --limit 10/s -j ACCEPT
sudo iptables -I ANTIDDOS -p tcp --dport 5432 --syn -j DROP
```

#### Make Rules Persistent

```bash
# Save iptables rules
sudo netfilter-persistent save

# Or for older systems
sudo iptables-save > /etc/iptables/rules.v4
```

### 4. Pterodactyl Panel Protection

#### Panel Web Server (Nginx/Apache)

```bash
# Rate limit HTTP/HTTPS
sudo iptables -I ANTIDDOS -p tcp --dport 80 -m limit --limit 100/s --limit-burst 200 -j ACCEPT
sudo iptables -I ANTIDDOS -p tcp --dport 443 -m limit --limit 100/s --limit-burst 200 -j ACCEPT

# Connection limits
sudo iptables -I ANTIDDOS -p tcp --dport 80 -m connlimit --connlimit-above 50 -j REJECT
sudo iptables -I ANTIDDOS -p tcp --dport 443 -m connlimit --connlimit-above 50 -j REJECT
```

#### Wings/Daemon Protection

```bash
# Protect Wings API (default port 8080)
sudo iptables -I ANTIDDOS -p tcp --dport 8080 -m connlimit --connlimit-above 30 -j REJECT
sudo iptables -I ANTIDDOS -p tcp --dport 8080 -m limit --limit 50/s -j ACCEPT

# Protect SFTP (if enabled)
sudo iptables -I ANTIDDOS -p tcp --dport 2022 -m connlimit --connlimit-above 10 -j REJECT
```

### 5. Start Services

```bash
# Start all services
sudo systemctl start antiddos-monitor
sudo systemctl start antiddos-ssh
sudo systemctl start antiddos-xcord

# Enable on boot
sudo systemctl enable antiddos-monitor
sudo systemctl enable antiddos-ssh
sudo systemctl enable antiddos-xcord

# Check status
sudo systemctl status antiddos-monitor
sudo systemctl status antiddos-ssh
sudo systemctl status antiddos-xcord
```

### 6. Verify Protection

```bash
# Check statistics
sudo antiddos-cli stats

# Check firewall rules
sudo iptables -L ANTIDDOS -n -v

# Check logs
sudo journalctl -u antiddos-monitor -f
```

## Post-Installation Configuration

### Create Custom Rules Script

Create `/etc/antiddos/custom-rules.sh`:

```bash
#!/bin/bash
# Custom firewall rules for Pterodactyl setup

# Database protection
iptables -I ANTIDDOS -p tcp --dport 3306 -m connlimit --connlimit-above 10 -j REJECT

# Panel protection
iptables -I ANTIDDOS -p tcp --dport 80 -m limit --limit 100/s --limit-burst 200 -j ACCEPT
iptables -I ANTIDDOS -p tcp --dport 443 -m limit --limit 100/s --limit-burst 200 -j ACCEPT

# Wings protection
iptables -I ANTIDDOS -p tcp --dport 8080 -m connlimit --connlimit-above 30 -j REJECT

# Game server ports (example: Minecraft)
iptables -I ANTIDDOS -p tcp --dport 25565 -m limit --limit 50/s -j ACCEPT
iptables -I ANTIDDOS -p udp --dport 25565 -m limit --limit 100/s -j ACCEPT

# Save rules
netfilter-persistent save
```

Make it executable:
```bash
sudo chmod +x /etc/antiddos/custom-rules.sh
```

Run on boot by editing `/etc/systemd/system/antiddos-monitor.service`:
```ini
[Service]
ExecStartPost=/etc/antiddos/custom-rules.sh
```

Then reload:
```bash
sudo systemctl daemon-reload
sudo systemctl restart antiddos-monitor
```

### Configure Backup

Create backup cron job:

```bash
sudo crontab -e
```

Add:
```cron
# Backup Anti-DDoS configuration daily at 2 AM
0 2 * * * tar -czf /backup/antiddos-$(date +\%Y\%m\%d).tar.gz /etc/antiddos/

# Clean old backups (keep 30 days)
0 3 * * * find /backup/antiddos-*.tar.gz -mtime +30 -delete
```

## Monitoring

### Real-Time Monitoring

```bash
# Monitor main service
sudo journalctl -u antiddos-monitor -f

# Monitor SSH protection
sudo journalctl -u antiddos-ssh -f

# Monitor all logs
sudo tail -f /var/log/antiddos/*.log

# Watch bandwidth
watch -n 1 'sudo antiddos-cli stats'
```

### Set Up Alerts

Edit `/etc/antiddos/config.yaml`:

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
    password: your_app_password  # Use app-specific password for Gmail
```

## Maintenance

### Daily Tasks

```bash
# Check for blocked IPs
sudo antiddos-cli blacklist list

# Check statistics
sudo antiddos-cli stats

# Review logs for issues
sudo grep -i "error\|warning" /var/log/antiddos/*.log
```

### Weekly Tasks

```bash
# Review whitelist
sudo antiddos-cli whitelist list

# Clean up old temporary bans
# (automatic, but verify)

# Check service health
sudo systemctl status antiddos-monitor antiddos-ssh antiddos-xcord
```

### Monthly Tasks

```bash
# Update GeoIP database
sudo antiddos-cli geoip update

# Review and optimize thresholds based on traffic patterns
# Edit /etc/antiddos/config.yaml as needed

# Backup configuration
sudo tar -czf ~/antiddos-backup-$(date +%Y%m%d).tar.gz /etc/antiddos/
```

## Troubleshooting

### Can't Access Panel After Installation

1. **Check if your IP is whitelisted:**
   ```bash
   sudo antiddos-cli whitelist list
   ```

2. **Temporarily disable protection:**
   ```bash
   sudo systemctl stop antiddos-monitor
   ```

3. **Check firewall rules:**
   ```bash
   sudo iptables -L ANTIDDOS -n -v
   ```

4. **Add your IP to whitelist:**
   ```bash
   sudo antiddos-cli whitelist add YOUR_IP
   sudo systemctl start antiddos-monitor
   ```

### Database Connection Issues

1. **Verify whitelist:**
   ```bash
   sudo antiddos-cli whitelist list | grep APP_SERVER_IP
   ```

2. **Check database port rules:**
   ```bash
   sudo iptables -L ANTIDDOS -n -v | grep 3306
   ```

3. **Temporarily allow all database connections:**
   ```bash
   sudo iptables -D ANTIDDOS -p tcp --dport 3306 -j DROP
   ```

### High False Positive Rate

1. **Increase thresholds:**
   Edit `/etc/antiddos/config.yaml`:
   ```yaml
   bandwidth:
     threshold_mbps: 2000  # Increase
     threshold_pps: 200000  # Increase
   
   dos_filter:
     syn_flood:
       threshold: 100  # Increase
     connection_limit:
       max_connections: 100  # Increase
   ```

2. **Reload configuration:**
   ```bash
   sudo antiddos-cli reload
   sudo systemctl restart antiddos-monitor
   ```

### Services Won't Start

1. **Check logs:**
   ```bash
   sudo journalctl -u antiddos-monitor -n 50
   ```

2. **Verify configuration:**
   ```bash
   python3 -c "import yaml; yaml.safe_load(open('/etc/antiddos/config.yaml'))"
   ```

3. **Check permissions:**
   ```bash
   sudo chown -R root:root /etc/antiddos
   sudo chmod 600 /etc/antiddos/config.yaml
   ```

## Security Best Practices

1. **Change default XCord keys immediately**
2. **Keep whitelist minimal** - only trusted IPs
3. **Monitor logs daily** for suspicious activity
4. **Regular backups** of configuration
5. **Test in staging** before production changes
6. **Document all custom rules**
7. **Keep system updated:**
   ```bash
   sudo apt update && sudo apt upgrade
   pip3 install --upgrade -r requirements.txt
   ```

## Emergency Procedures

### Complete Shutdown

If Anti-DDoS is causing issues:

```bash
# Stop all services
sudo systemctl stop antiddos-monitor antiddos-ssh antiddos-xcord

# Remove firewall rules
sudo iptables -D INPUT -j ANTIDDOS
sudo iptables -F ANTIDDOS
sudo iptables -X ANTIDDOS
```

### Quick Recovery

```bash
# Restore from backup
sudo tar -xzf /backup/antiddos-YYYYMMDD.tar.gz -C /

# Restart services
sudo systemctl start antiddos-monitor antiddos-ssh antiddos-xcord
```

## Support and Resources

- Configuration file: `/etc/antiddos/config.yaml`
- Logs: `/var/log/antiddos/`
- CLI help: `antiddos-cli --help`
- Service status: `systemctl status antiddos-monitor`

For additional help, see:
- `README.md` - General documentation
- `QUICKSTART.md` - Quick start guide
- `docs/ADVANCED.md` - Advanced configuration
