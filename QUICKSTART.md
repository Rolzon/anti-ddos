# Quick Start Guide

## Installation

1. **Clone or download the repository**
   ```bash
   cd /opt
   git clone <repository-url> anti-ddos
   cd anti-ddos
   ```

2. **Run installation script**
   ```bash
   sudo chmod +x install.sh
   sudo ./install.sh
   ```

## Initial Configuration

### 1. Configure Network Interface

Edit `/etc/antiddos/config.yaml`:

```yaml
bandwidth:
  interface: eth0  # Change to your network interface (use 'ip a' to find it)
```

### 2. Whitelist Your IP (IMPORTANT!)

Before enabling any filters, whitelist your own IP to avoid locking yourself out:

```bash
sudo antiddos-cli whitelist add YOUR_IP_ADDRESS
```

### 3. Configure XCord Encryption (if using multiple servers)

Edit `/etc/antiddos/config.yaml`:

```yaml
xcord:
  enabled: true
  encryption_key: "YOUR_SECURE_32_CHAR_KEY_HERE"
  auth_token: "YOUR_SECURE_TOKEN_HERE"
  peers:
    - "192.168.1.100:9999"  # Add your other server IPs
```

**Generate secure keys:**
```bash
# For encryption key (32+ characters)
openssl rand -base64 32

# For auth token
openssl rand -hex 32
```

### 4. Configure Country Blocking

Edit `/etc/antiddos/config.yaml`:

```yaml
country_filter:
  enabled: true
  mode: blacklist
  blacklist:
    - CN  # China
    - RU  # Russia
    - KP  # North Korea
    # Add more as needed
```

## Start Services

```bash
# Start all services
sudo systemctl start antiddos-monitor
sudo systemctl start antiddos-ssh
sudo systemctl start antiddos-xcord

# Enable on boot
sudo systemctl enable antiddos-monitor
sudo systemctl enable antiddos-ssh
sudo systemctl enable antiddos-xcord
```

## Verify Installation

```bash
# Check service status
sudo systemctl status antiddos-monitor

# View statistics
sudo antiddos-cli stats

# View logs
sudo journalctl -u antiddos-monitor -f
```

## Common Operations

### Block an IP
```bash
sudo antiddos-cli blacklist add 1.2.3.4
```

### Unblock an IP
```bash
sudo antiddos-cli blacklist remove 1.2.3.4
```

### List blocked IPs
```bash
sudo antiddos-cli blacklist list
```

### Block a country
```bash
sudo antiddos-cli country block CN
```

### Whitelist an IP (bypass all filters)
```bash
sudo antiddos-cli whitelist add 5.6.7.8
```

### View current statistics
```bash
sudo antiddos-cli stats
```

### Reload configuration
```bash
sudo antiddos-cli reload
sudo systemctl restart antiddos-monitor
```

## Protecting Pterodactyl and Databases

### For Pterodactyl Panel

1. **Whitelist Pterodactyl server IP**
   ```bash
   sudo antiddos-cli whitelist add PTERODACTYL_SERVER_IP
   ```

2. **Configure stricter limits for web traffic**
   Edit `/etc/antiddos/config.yaml`:
   ```yaml
   dos_filter:
     connection_limit:
       max_connections: 30  # Adjust based on your needs
   ```

### For Database Servers

1. **Whitelist application server IPs**
   ```bash
   sudo antiddos-cli whitelist add APP_SERVER_IP_1
   sudo antiddos-cli whitelist add APP_SERVER_IP_2
   ```

2. **Enable strict SSH protection**
   Edit `/etc/antiddos/config.yaml`:
   ```yaml
   ssh_protection:
     enabled: true
     max_attempts: 3  # Stricter limit
     ban_time: 7200   # 2 hours
   ```

3. **Configure MySQL/PostgreSQL port protection**
   Add custom iptables rules for database ports:
   ```bash
   # For MySQL (port 3306)
   sudo iptables -I ANTIDDOS -p tcp --dport 3306 -m connlimit --connlimit-above 10 -j REJECT
   
   # For PostgreSQL (port 5432)
   sudo iptables -I ANTIDDOS -p tcp --dport 5432 -m connlimit --connlimit-above 10 -j REJECT
   ```

## Monitoring

### Real-time monitoring
```bash
# Monitor main service
sudo journalctl -u antiddos-monitor -f

# Monitor SSH protection
sudo journalctl -u antiddos-ssh -f

# Monitor XCord
sudo journalctl -u antiddos-xcord -f

# View all logs
sudo tail -f /var/log/antiddos/*.log
```

### Check bandwidth usage
```bash
# Install vnstat for historical data
sudo apt install vnstat
sudo vnstat -i eth0
```

## Troubleshooting

### Can't connect after installation
1. Check if your IP is whitelisted:
   ```bash
   sudo antiddos-cli whitelist list
   ```

2. Temporarily disable filters:
   ```bash
   sudo systemctl stop antiddos-monitor
   ```

3. Check firewall rules:
   ```bash
   sudo iptables -L ANTIDDOS -n -v
   ```

### Services won't start
1. Check logs:
   ```bash
   sudo journalctl -u antiddos-monitor -n 50
   ```

2. Verify configuration:
   ```bash
   python3 -c "import yaml; yaml.safe_load(open('/etc/antiddos/config.yaml'))"
   ```

3. Check permissions:
   ```bash
   sudo chown -R root:root /etc/antiddos
   sudo chmod 600 /etc/antiddos/config.yaml
   ```

### High false positive rate
1. Increase thresholds in `/etc/antiddos/config.yaml`:
   ```yaml
   bandwidth:
     threshold_mbps: 2000  # Increase
     threshold_pps: 200000  # Increase
   
   dos_filter:
     syn_flood:
       threshold: 100  # Increase
   ```

2. Reload configuration:
   ```bash
   sudo antiddos-cli reload
   sudo systemctl restart antiddos-monitor
   ```

## Security Best Practices

1. **Change default keys immediately**
   - XCord encryption key
   - XCord auth token

2. **Regularly update GeoIP database**
   ```bash
   sudo antiddos-cli geoip update
   ```

3. **Monitor logs daily**
   ```bash
   sudo grep -i "banned\|blocked" /var/log/antiddos/*.log
   ```

4. **Keep whitelist minimal**
   - Only add trusted IPs
   - Review regularly

5. **Test before production**
   - Test all filters in staging environment
   - Verify legitimate traffic isn't blocked

6. **Backup configuration**
   ```bash
   sudo cp /etc/antiddos/config.yaml ~/antiddos-config-backup.yaml
   ```

## Support

For issues, questions, or contributions:
- Check logs: `/var/log/antiddos/`
- Review configuration: `/etc/antiddos/config.yaml`
- See README.md for detailed documentation
