# Changelog

All notable changes to this project will be documented in this file.

## [1.0.1] - 2024-11-12

### Security Enhancements
- **CRITICAL**: Added protection for Docker/Pterodactyl firewall rules
- Protected chains: DOCKER, DOCKER-ISOLATION-STAGE-1, DOCKER-ISOLATION-STAGE-2, DOCKER-USER
- Explicit protection for Pterodactyl Wings subnet (172.18.0.0/16)
- Automatic blocking of dangerous iptables operations (NAT flush, FORWARD policy changes)
- Safe cleanup that preserves Docker/Pterodactyl rules

### Changed
- `firewall.py`: Added `PROTECTED_CHAINS` and `PROTECTED_SUBNETS` constants
- `firewall.py`: Added `_is_protected_chain_modification()` validation method
- `firewall.py`: Added `_is_dangerous_operation()` validation method
- `firewall.py`: Enhanced `_add_docker_exceptions()` with bidirectional subnet rules
- `uninstall.sh`: Modified to preserve Docker/Pterodactyl rules
- `complete-uninstall.sh`: Changed to only clean ANTIDDOS chain, not all iptables

### Added
- New documentation: `docs/FIREWALL_SAFETY.md` with complete safety guidelines
- Logging of blocked dangerous operations
- FORWARD chain protection for Docker traffic

### Fixed
- Prevented accidental deletion of Docker NAT rules
- Prevented modification of critical Docker chains
- Ensured Pterodactyl Wings subnet is always allowed

## [1.0.0] - 2024-11-09

### Added
- Initial release of Anti-DDoS protection system
- Dynamic country filtering with GeoIP support
- Bandwidth and PPS monitoring with automatic triggers
- Global blacklist and whitelist management
- DoS protection filters (SYN/UDP/ICMP flood)
- SSH failed attempt monitoring (Fail2ban-like)
- XCord encrypted blacklist synchronization
- Command-line interface (CLI) for management
- Systemd service integration
- Comprehensive documentation
- Installation and uninstallation scripts
- Configuration examples for Pterodactyl
- Diagnostic and update scripts

### Features
- **Bandwidth Monitoring**: Real-time monitoring with configurable thresholds
- **Country Filtering**: Block/allow countries based on GeoIP
- **Automatic Mitigation**: Trigger protections based on traffic patterns
- **SSH Protection**: Monitor auth logs and ban attackers
- **Distributed Sync**: Share blacklists across multiple servers with encryption
- **Flexible Configuration**: YAML-based with hot-reload support
- **CLI Management**: Easy command-line interface for all operations
- **Kernel Hardening**: Automatic sysctl tuning for security

### Security
- Fernet encryption for XCord communication
- Token-based authentication for peer connections
- Whitelist override for trusted IPs
- Configurable ban durations
- Audit logging for all actions

### Documentation
- Complete README with installation guide
- Quick start guide (English and Spanish)
- Advanced configuration guide
- Pterodactyl-specific deployment guide
- Project structure documentation
- Example configurations and scripts

### Compatibility
- Ubuntu 22.04 LTS (primary target)
- Python 3.10+
- iptables-based firewall
- Systemd service manager

## Future Releases

### Planned for 1.1.0
- [ ] IPv6 full support
- [ ] nftables support
- [ ] Web dashboard
- [ ] Prometheus metrics exporter
- [ ] Enhanced notification system
- [ ] Machine learning for attack detection

### Planned for 1.2.0
- [ ] Docker container support
- [ ] Ansible playbook
- [ ] Cloud provider integration (AWS, GCP, Azure)
- [ ] Advanced traffic analysis
- [ ] Custom plugin system

---

For more information, see README.md
