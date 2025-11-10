# Project Structure

```
anti-ddos/
├── README.md                          # Main documentation
├── QUICKSTART.md                      # Quick start guide
├── LICENSE                            # MIT License
├── requirements.txt                   # Python dependencies
├── setup.py                          # Python package setup
├── .gitignore                        # Git ignore rules
│
├── config/
│   └── config.yaml                   # Main configuration file
│
├── src/
│   └── antiddos/
│       ├── __init__.py               # Package initialization
│       ├── config.py                 # Configuration management
│       ├── monitor.py                # Main monitoring daemon
│       ├── firewall.py               # Firewall/iptables management
│       ├── geoip.py                  # GeoIP country filtering
│       ├── blacklist.py              # Blacklist/whitelist management
│       ├── ssh_protection.py         # SSH failed attempt monitoring
│       ├── xcord.py                  # XCord encrypted blacklist sync
│       └── cli.py                    # Command-line interface
│
├── systemd/
│   ├── antiddos-monitor.service      # Main monitoring service
│   ├── antiddos-ssh.service          # SSH protection service
│   └── antiddos-xcord.service        # XCord service
│
├── docs/
│   ├── ADVANCED.md                   # Advanced configuration guide
│   └── PTERODACTYL_DEPLOYMENT.md     # Pterodactyl-specific deployment
│
├── install.sh                        # Installation script
├── uninstall.sh                      # Uninstallation script
└── test_installation.sh              # Installation test script
```

## Component Overview

### Core Modules

#### 1. **monitor.py** - Main Daemon
- Bandwidth monitoring (Mbps/PPS)
- Automatic mitigation triggers
- Connection tracking
- DoS attack detection
- Integration with all other modules

#### 2. **firewall.py** - Firewall Management
- iptables rule management
- Custom ANTIDDOS chain
- Kernel hardening (sysctl)
- DoS filters (SYN/UDP/ICMP flood)
- Connection limits
- IP blocking/unblocking

#### 3. **geoip.py** - Country Filtering
- GeoIP database integration
- Country-based blocking
- Blacklist/whitelist modes
- Dynamic activation on bandwidth threshold
- IP range management

#### 4. **blacklist.py** - IP Management
- Permanent and temporary bans
- Whitelist management
- Auto-save functionality
- File-based persistence
- Automatic cleanup of expired bans

#### 5. **ssh_protection.py** - SSH Security
- Auth log monitoring
- Failed attempt tracking
- Automatic IP banning
- Custom warning banners
- Configurable thresholds

#### 6. **xcord.py** - Distributed Sync
- Encrypted communication (Fernet)
- Multi-server blacklist sync
- Authentication tokens
- Peer-to-peer architecture
- Real-time updates

#### 7. **cli.py** - Management Interface
- Blacklist/whitelist management
- Country blocking
- Statistics viewing
- Configuration reload
- GeoIP updates

### Configuration

#### config.yaml Structure

```yaml
general:           # Logging, intervals, paths
bandwidth:         # Monitoring thresholds
country_filter:    # GeoIP blocking
blacklist:         # IP blacklist settings
dos_filter:        # DoS protection rules
ssh_protection:    # SSH security settings
xcord:            # Distributed sync
whitelist:        # Trusted IPs
notifications:    # Email/webhook alerts
advanced:         # Kernel tuning
```

### Services

#### antiddos-monitor.service
- Main monitoring daemon
- Bandwidth tracking
- Automatic mitigation
- Runs continuously

#### antiddos-ssh.service
- SSH log monitoring
- Failed attempt tracking
- Automatic banning
- Runs continuously

#### antiddos-xcord.service
- Blacklist synchronization
- Encrypted communication
- Peer management
- Runs continuously

## Data Flow

```
Network Traffic
    ↓
iptables (ANTIDDOS chain)
    ↓
Bandwidth Monitor → Threshold Check
    ↓                      ↓
Normal Traffic      High Traffic
    ↓                      ↓
Allow            Activate Mitigation
                         ↓
                 ┌───────┴────────┐
                 ↓                ↓
          Country Filter    DoS Filter
                 ↓                ↓
          Block/Allow      Rate Limit
                 ↓                ↓
              Firewall Rules Applied
                       ↓
                 XCord Sync
                       ↓
              Other Servers Updated
```

## File Locations (After Installation)

```
/etc/antiddos/
├── config.yaml              # Main configuration
├── blacklist.txt           # Blocked IPs
└── whitelist.txt           # Trusted IPs

/var/log/antiddos/
├── antiddos.log            # Main log
├── ssh-protection.log      # SSH protection log
└── xcord.log              # XCord sync log

/usr/share/GeoIP/
└── GeoLite2-Country.mmdb   # GeoIP database

/etc/systemd/system/
├── antiddos-monitor.service
├── antiddos-ssh.service
└── antiddos-xcord.service

/usr/local/bin/
└── antiddos-cli            # CLI command
```

## Key Features Summary

### ✅ Dynamic Country Filtering
- GeoIP-based blocking
- Blacklist/whitelist modes
- Automatic activation on high traffic
- Configurable country lists

### ✅ Bandwidth Monitoring
- Real-time Mbps/PPS tracking
- Configurable thresholds
- Automatic mitigation triggers
- Per-interface monitoring

### ✅ Global Blacklist
- Permanent and temporary bans
- File-based persistence
- Auto-cleanup of expired bans
- Whitelist override

### ✅ DoS Protection
- SYN flood protection
- UDP flood protection
- ICMP flood protection
- Connection limits per IP

### ✅ SSH Protection
- Failed attempt monitoring
- Automatic banning
- Custom warning banners
- Configurable thresholds

### ✅ XCord Sync
- Encrypted communication
- Multi-server support
- Real-time synchronization
- Authentication required

### ✅ Highly Configurable
- YAML configuration
- Hot-reload support
- Per-feature enable/disable
- Extensive tuning options

## CLI Commands Reference

```bash
# Blacklist Management
antiddos-cli blacklist add <ip> [-r "reason"]
antiddos-cli blacklist remove <ip>
antiddos-cli blacklist list

# Whitelist Management
antiddos-cli whitelist add <ip>
antiddos-cli whitelist remove <ip>
antiddos-cli whitelist list

# Country Filtering
antiddos-cli country block <code>
antiddos-cli country unblock <code>
antiddos-cli country lookup <ip>

# GeoIP Management
antiddos-cli geoip update

# System Management
antiddos-cli stats
antiddos-cli reload
antiddos-cli test
```

## Service Management

```bash
# Start services
systemctl start antiddos-monitor
systemctl start antiddos-ssh
systemctl start antiddos-xcord

# Stop services
systemctl stop antiddos-monitor
systemctl stop antiddos-ssh
systemctl stop antiddos-xcord

# Restart services
systemctl restart antiddos-monitor

# Enable on boot
systemctl enable antiddos-monitor
systemctl enable antiddos-ssh
systemctl enable antiddos-xcord

# Check status
systemctl status antiddos-monitor

# View logs
journalctl -u antiddos-monitor -f
```

## Dependencies

### System Packages
- python3 (3.10+)
- python3-pip
- iptables
- iptables-persistent
- conntrack
- net-tools

### Python Packages
- pyyaml (6.0.1)
- psutil (5.9.5)
- geoip2 (4.7.0)
- maxminddb (2.4.0)
- cryptography (41.0.4)
- requests (2.31.0)
- python-iptables (1.0.1)
- watchdog (3.0.0)

## Security Considerations

1. **Configuration File**: Contains sensitive keys, should be chmod 600
2. **XCord Keys**: Must be changed from defaults in production
3. **Whitelist**: Keep minimal, only trusted IPs
4. **Root Access**: Required for iptables and system monitoring
5. **Log Files**: May contain sensitive IP information
6. **GeoIP Database**: Requires MaxMind account for updates

## Performance Impact

- **CPU**: Low (~1-2% on idle, 5-10% under attack)
- **Memory**: ~50-100MB per service
- **Network**: Minimal overhead (<1% bandwidth)
- **Disk**: Log files grow over time (use logrotate)

## Compatibility

- **OS**: Ubuntu 22.04 LTS (primary target)
- **Kernel**: 5.15+ (for modern iptables features)
- **Python**: 3.10+
- **IPv4**: Full support
- **IPv6**: Partial support (can be extended)

## Future Enhancements

- [ ] IPv6 full support
- [ ] nftables support (alternative to iptables)
- [ ] Web dashboard
- [ ] Machine learning for attack detection
- [ ] Integration with cloud providers (AWS, GCP, Azure)
- [ ] Prometheus metrics exporter
- [ ] Docker container support
- [ ] Ansible playbook for deployment
