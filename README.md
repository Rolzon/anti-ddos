# Anti-DDoS Protection System for Ubuntu 22.04

A comprehensive DDoS protection system designed to protect servers running databases and Pterodactyl.

## Features

- **Dynamic Country Filtering**: GeoIP-based country blocking with configurable whitelist/blacklist
- **Bandwidth Monitoring**: Real-time bandwidth and PPS (packets per second) monitoring with automatic triggers
- **Global Blacklist**: Centralized IP blacklist management
- **DoS Filter**: Automatic detection and mitigation of DoS attacks
- **SSH Protection**: Failed SSH attempt monitoring with automatic banning (Fail2ban-like)
- **XCord Blacklist Handler**: Encrypted blacklist synchronization across multiple servers
- **Highly Configurable**: YAML-based configuration with hot-reload support

## Requirements

- Ubuntu 22.04 LTS
- Python 3.10+
- iptables
- Root/sudo access

## Installation

```bash
sudo ./install.sh
```

## Configuration

Edit `/etc/antiddos/config.yaml` to customize settings:

- Bandwidth thresholds
- Country filters
- SSH protection rules
- XCord encryption keys
- Whitelist/blacklist rules

## Services

- `antiddos-monitor.service` - Main monitoring daemon
- `antiddos-ssh.service` - SSH protection service
- `antiddos-xcord.service` - XCord blacklist handler

## Usage

```bash
# Start all services
sudo systemctl start antiddos-monitor antiddos-ssh antiddos-xcord

# Enable on boot
sudo systemctl enable antiddos-monitor antiddos-ssh antiddos-xcord

# Check status
sudo systemctl status antiddos-monitor

# View logs
sudo journalctl -u antiddos-monitor -f
```

## Management CLI

```bash
# Add IP to blacklist
sudo antiddos-cli blacklist add 1.2.3.4

# Remove IP from blacklist
sudo antiddos-cli blacklist remove 1.2.3.4

# List blocked IPs
sudo antiddos-cli blacklist list

# Add country to block
sudo antiddos-cli country block CN

# Whitelist an IP (bypass all filters)
sudo antiddos-cli whitelist add 5.6.7.8

# View current statistics
sudo antiddos-cli stats

# Reload configuration
sudo antiddos-cli reload
```

## Security Notes

- Keep XCord encryption keys secure
- Regularly update GeoIP databases
- Monitor logs for false positives
- Test whitelist before deploying country blocks

## License

MIT License
