"""
Firewall management using iptables
"""

import subprocess
import logging
from typing import List, Optional


class FirewallManager:
    """Manage iptables rules for DDoS protection"""
    
    # Protected chains that should NEVER be modified or deleted
    PROTECTED_CHAINS = ['DOCKER', 'DOCKER-ISOLATION-STAGE-1', 'DOCKER-ISOLATION-STAGE-2', 'DOCKER-USER']
    
    # Protected subnets (Docker/Pterodactyl networks)
    PROTECTED_SUBNETS = [
        '172.16.0.0/12',  # Docker default range
        '172.18.0.0/16',  # Pterodactyl Wings specific subnet
        '10.0.0.0/8',     # Private network
        '192.168.0.0/16', # Private network
        '127.0.0.0/8'     # Loopback
    ]
    
    def __init__(self, config):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.chain_name = "ANTIDDOS"
        self.strict_chain = f"{self.chain_name}_GLOBAL"
        
        # Use iptables-nft for compatibility with Docker/Pterodactyl
        self.iptables_cmd = self._detect_iptables()
        self.logger.info(f"Using iptables binary: {self.iptables_cmd}")
    
    def _detect_iptables(self) -> str:
        """Detect which iptables binary to use - prefer nft for Docker compatibility"""
        # Try iptables-nft first (required for Docker/Pterodactyl)
        try:
            result = subprocess.run(
                ['iptables-nft', '-L', '-n'],
                capture_output=True,
                check=False,
                timeout=5
            )
            if result.returncode == 0:
                self.logger.info("Using iptables-nft (Docker/Pterodactyl compatible)")
                return 'iptables-nft'
        except:
            pass
        
        # Try regular iptables (usually points to nft on modern systems)
        try:
            result = subprocess.run(
                ['iptables', '-L', '-n'],
                capture_output=True,
                check=False,
                timeout=5
            )
            if result.returncode == 0:
                # Check if it's using nft backend
                version_result = subprocess.run(
                    ['iptables', '--version'],
                    capture_output=True,
                    text=True,
                    check=False
                )
                if 'nf_tables' in version_result.stdout:
                    self.logger.info("Using iptables with nf_tables backend")
                    return 'iptables'
        except:
            pass
        
        # Fallback to regular iptables
        self.logger.warning("Could not detect nft backend, using default iptables")
        return 'iptables'
    
    def run_command(self, cmd: List[str]) -> bool:
        """Run iptables command with safety checks"""
        try:
            # Safety check: prevent modification of protected chains
            if self._is_protected_chain_modification(cmd):
                self.logger.warning(f"BLOCKED: Attempted to modify protected chain: {' '.join(cmd)}")
                return False
            
            # Safety check: prevent deletion/flush of DOCKER chains
            if self._is_dangerous_operation(cmd):
                self.logger.warning(f"BLOCKED: Dangerous operation prevented: {' '.join(cmd)}")
                return False
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False
            )
            if result.returncode != 0:
                self.logger.error(f"Command failed: {' '.join(cmd)}")
                self.logger.error(f"Error: {result.stderr}")
                return False
            return True
        except Exception as e:
            self.logger.error(f"Error running command: {e}")
            return False
    
    def _is_protected_chain_modification(self, cmd: List[str]) -> bool:
        """Check if command attempts to modify protected chains"""
        cmd_str = ' '.join(cmd)
        
        # Check for operations on protected chains
        for chain in self.PROTECTED_CHAINS:
            # Block deletion, flush, or modification of protected chains
            if any([
                f'-X {chain}' in cmd_str,  # Delete chain
                f'-F {chain}' in cmd_str,  # Flush chain
                f'-D {chain}' in cmd_str,  # Delete rule from chain
                f'-R {chain}' in cmd_str,  # Replace rule in chain
                (f'-A {chain}' in cmd_str or f'-I {chain}' in cmd_str) and self.chain_name not in cmd_str
            ]):
                return True
        
        return False
    
    def _is_dangerous_operation(self, cmd: List[str]) -> bool:
        """Check if command is a dangerous operation"""
        cmd_str = ' '.join(cmd)
        
        # Block operations that could break Docker/Pterodactyl
        dangerous_patterns = [
            '-t nat -F',           # Flush NAT table (breaks Docker)
            '-t nat -X',           # Delete NAT chains
            'FORWARD -P DROP',     # Change FORWARD policy to DROP
            'FORWARD -F',          # Flush FORWARD chain
        ]
        
        for pattern in dangerous_patterns:
            if pattern in cmd_str:
                return True
        
        return False
    
    def initialize(self):
        """Initialize firewall rules - Docker/Pterodactyl compatible"""
        self.logger.info("Initializing firewall rules (nft compatible)")
        
        # Create custom chain if it doesn't exist
        self.run_command([self.iptables_cmd, '-N', self.chain_name])
        
        # Flush existing rules in our chain
        self.run_command([self.iptables_cmd, '-F', self.chain_name])
        
        # Add Docker/Pterodactyl exceptions FIRST (before ANTIDDOS chain)
        self._add_docker_exceptions()
        
        # Add MySQL exceptions for server public IP
        self._add_mysql_exceptions()

        # Apply MySQL protection if enabled
        self.apply_mysql_protection()
        
        # Apply Wings API protection if enabled
        self.apply_wings_api_protection()
        
        # Insert our chain into INPUT (for traffic to host itself)
        # Check if jump already exists to avoid duplicates
        check_result = subprocess.run(
            [self.iptables_cmd, '-C', 'INPUT', '-j', self.chain_name],
            capture_output=True,
            check=False
        )
        if check_result.returncode != 0:
            self.run_command([self.iptables_cmd, '-A', 'INPUT', '-j', self.chain_name])
        
        # CRITICAL: Insert our chain into FORWARD (for traffic to Docker containers)
        # This MUST be before Docker rules so we can block attackers before NAT
        check_forward = subprocess.run(
            [self.iptables_cmd, '-C', 'FORWARD', '-j', self.chain_name],
            capture_output=True,
            check=False
        )
        if check_forward.returncode != 0:
            # Insert at position 1 so it's evaluated before Docker ACCEPT rules
            self.run_command([self.iptables_cmd, '-I', 'FORWARD', '1', '-j', self.chain_name])
            self.logger.info("Added ANTIDDOS chain to FORWARD for Docker traffic filtering")
        
        # Apply kernel hardening if configured
        if self.config.get('advanced.kernel_hardening', True):
            self.apply_kernel_hardening()
        
        # Apply DoS filters
        if self.config.get('dos_filter.enabled', True):
            self.apply_dos_filters()
        
        self.logger.info("Firewall rules initialized")
    
    def _add_docker_exceptions(self):
        """Add exceptions for Docker/Pterodactyl - these bypass ANTIDDOS"""
        self.logger.info("Adding Docker/Pterodactyl exceptions")
        
        # Allow all Docker traffic (critical for Pterodactyl)
        self.run_command([self.iptables_cmd, '-I', 'INPUT', '1', '-i', 'docker0', '-j', 'ACCEPT'])
        self.run_command([self.iptables_cmd, '-I', 'INPUT', '1', '-i', 'pterodactyl0', '-j', 'ACCEPT'])
        self.run_command([self.iptables_cmd, '-I', 'INPUT', '1', '-i', 'pterodactyl_nw', '-j', 'ACCEPT'])
        
        # Allow established connections (critical for Docker NAT)
        self.run_command([self.iptables_cmd, '-I', 'INPUT', '1', '-m', 'conntrack', '--ctstate', 'ESTABLISHED,RELATED', '-j', 'ACCEPT'])
        
        # Allow loopback
        self.run_command([self.iptables_cmd, '-I', 'INPUT', '1', '-i', 'lo', '-j', 'ACCEPT'])
        
        # Allow Docker networks - using PROTECTED_SUBNETS to ensure consistency
        for network in self.PROTECTED_SUBNETS:
            self.run_command([self.iptables_cmd, '-I', 'INPUT', '1', '-s', network, '-j', 'ACCEPT'])
            self.run_command([self.iptables_cmd, '-I', 'INPUT', '1', '-d', network, '-j', 'ACCEPT'])
        
        # CRITICAL: Ensure FORWARD chain allows Docker traffic
        self.run_command([self.iptables_cmd, '-I', 'FORWARD', '1', '-i', 'docker0', '-j', 'ACCEPT'])
        self.run_command([self.iptables_cmd, '-I', 'FORWARD', '1', '-o', 'docker0', '-j', 'ACCEPT'])
        
        self.logger.info("Docker exceptions added with full subnet protection")

    def _get_port_chain_name(self, port: int) -> str:
        return f"{self.chain_name}_PORT_{port}"

    def _chain_exists(self, chain_name: str) -> bool:
        result = subprocess.run(
            [self.iptables_cmd, '-L', chain_name],
            capture_output=True,
            check=False
        )
        return result.returncode == 0

    def _ensure_chain(self, chain_name: str, flush: bool = True):
        if not self._chain_exists(chain_name):
            self.run_command([self.iptables_cmd, '-N', chain_name])
        elif flush:
            self.run_command([self.iptables_cmd, '-F', chain_name])

    def _add_whitelist_bypass(self, chain_name: str):
        whitelist_cfg = self.config.get('whitelist', {}) or {}
        whitelist_ips = whitelist_cfg.get('ips', []) or []
        for ip in whitelist_ips:
            ip = (ip or '').strip()
            if not ip:
                continue
            self.run_command([
                self.iptables_cmd, '-A', chain_name,
                '-s', ip,
                '-j', 'RETURN'
            ])

    def _ensure_jump(self, chain_name: str, protocol: Optional[str] = None, port: Optional[int] = None):
        check_cmd = [self.iptables_cmd, '-C', self.chain_name]
        insert_cmd = [self.iptables_cmd, '-I', self.chain_name, '1']
        if protocol:
            check_cmd += ['-p', protocol]
            insert_cmd += ['-p', protocol]
        if port:
            check_cmd += ['--dport', str(port)]
            insert_cmd += ['--dport', str(port)]
        check_cmd += ['-j', chain_name]
        insert_cmd += ['-j', chain_name]

        result = subprocess.run(check_cmd, capture_output=True, check=False)
        if result.returncode != 0:
            self.run_command(insert_cmd)

    def _remove_jump(self, chain_name: str, protocol: Optional[str] = None, port: Optional[int] = None):
        while True:
            cmd = [self.iptables_cmd, '-D', self.chain_name]
            if protocol:
                cmd += ['-p', protocol]
            if port:
                cmd += ['--dport', str(port)]
            cmd += ['-j', chain_name]
            result = subprocess.run(cmd, capture_output=True, check=False)
            if result.returncode != 0:
                break

    def apply_port_rate_limit(self, port: int, protocol: str = 'tcp', limit_pps: int = 20000) -> bool:
        """Apply rate limiting rules for a specific port"""
        protocol = (protocol or 'tcp').lower()
        if protocol not in ('tcp', 'udp'):
            self.logger.warning(f"Unsupported protocol {protocol} for port rate limit")
            return False

        chain_name = self._get_port_chain_name(port)
        limit_pps = max(1, int(limit_pps))
        burst = max(limit_pps * 2, limit_pps + 10)

        self.logger.info(
            f"Applying rate limit to port {port}/{protocol}: {limit_pps} PPS"
        )

        self._ensure_chain(chain_name)

        self._add_whitelist_bypass(chain_name)

        # Allow limited traffic then drop the rest
        self.run_command([
            self.iptables_cmd, '-A', chain_name,
            '-p', protocol,
            '-m', 'limit', '--limit', f'{limit_pps}/second', '--limit-burst', str(burst),
            '-j', 'RETURN'
        ])

        self.run_command([
            self.iptables_cmd, '-A', chain_name,
            '-j', 'DROP'
        ])

        self._ensure_jump(chain_name, protocol=protocol, port=port)

        return True

    def block_port(self, port: int, protocol: str = 'udp') -> bool:
        """Drop all traffic to a port (except whitelist)"""
        protocol = (protocol or 'udp').lower()
        if protocol not in ('tcp', 'udp'):
            self.logger.warning(f"Unsupported protocol {protocol} for port block")
            return False

        chain_name = self._get_port_chain_name(port)
        self.logger.info(f"Blocking port {port}/{protocol} for suspicious traffic")

        self._ensure_chain(chain_name)
        self._add_whitelist_bypass(chain_name)

        self.run_command([
            self.iptables_cmd, '-A', chain_name,
            '-j', 'DROP'
        ])

        self._ensure_jump(chain_name, protocol=protocol, port=port)
        return True

    def remove_port_rate_limit(self, port: int, protocol: str = 'tcp') -> bool:
        """Remove rate limiting rules for a specific port"""
        protocol = (protocol or 'tcp').lower()
        if protocol not in ('tcp', 'udp'):
            return False

        chain_name = self._get_port_chain_name(port)
        self.logger.info(f"Removing rate limit from port {port}/{protocol}")

        self._remove_jump(chain_name, protocol=protocol, port=port)

        # Flush and delete chain
        self.run_command([self.iptables_cmd, '-F', chain_name])
        self.run_command([self.iptables_cmd, '-X', chain_name])

        return True

    def unblock_port(self, port: int, protocol: str = 'tcp') -> bool:
        """Alias for removing per-port chains"""
        return self.remove_port_rate_limit(port, protocol)

    def _add_mysql_exceptions(self):
        """Add exceptions for MySQL from server public IP"""
        mysql_config = self.config.get('advanced.mysql', {})
        
        if mysql_config.get('allow_server_public_ip', False):
            server_ip = mysql_config.get('server_public_ip', '')
            mysql_port = mysql_config.get('port', 3306)
            
            if server_ip:
                self.logger.info(f"Adding MySQL exception for {server_ip}:{mysql_port}")
                self.run_command([
                    self.iptables_cmd, '-I', 'INPUT', '1',
                    '-s', server_ip,
                    '-p', 'tcp', '--dport', str(mysql_port),
                    '-j', 'ACCEPT'
                ])
                self.run_command([
                    self.iptables_cmd, '-I', 'INPUT', '1',
                    '-s', '127.0.0.1',
                    '-p', 'tcp', '--dport', str(mysql_port),
                    '-j', 'ACCEPT'
                ])
    
    def apply_mysql_protection(self):
        """Apply advanced MySQL protection with rate limiting and connection tracking"""
        mysql_config = self.config.get('advanced.mysql', {})
        
        if not mysql_config.get('protection_enabled', True):
            return
        
        mysql_port = mysql_config.get('port', 3306)
        trusted_ips = mysql_config.get('trusted_ips', ['127.0.0.1'])
        rate_limit = mysql_config.get('rate_limit', '10/s')
        rate_limit_burst = mysql_config.get('rate_limit_burst', 40)
        max_connections = mysql_config.get('max_connections_per_ip', 10)
        
        self.logger.info(f"Applying MySQL protection on port {mysql_port}")
        
        chain_name = f"ANTIDDOS_MYSQL_{mysql_port}"
        self._ensure_chain(chain_name)
        
        # Allow trusted IPs without limits
        for ip in trusted_ips:
            if ip and ip.strip():
                self.run_command([
                    self.iptables_cmd, '-A', chain_name,
                    '-s', ip.strip(),
                    '-j', 'ACCEPT'
                ])
        
        # Rate limit new connections
        parts = rate_limit.split('/')
        if len(parts) == 2:
            limit_value, limit_unit = parts
            self.run_command([
                self.iptables_cmd, '-A', chain_name,
                '-p', 'tcp', '--dport', str(mysql_port),
                '-m', 'state', '--state', 'NEW',
                '-m', 'limit', '--limit', rate_limit, '--limit-burst', str(rate_limit_burst),
                '-j', 'ACCEPT'
            ])
        
        # Limit concurrent connections per IP
        self.run_command([
            self.iptables_cmd, '-A', chain_name,
            '-p', 'tcp', '--dport', str(mysql_port),
            '-m', 'connlimit', '--connlimit-above', str(max_connections),
            '-j', 'DROP'
        ])
        
        # Accept established connections
        self.run_command([
            self.iptables_cmd, '-A', chain_name,
            '-p', 'tcp', '--dport', str(mysql_port),
            '-m', 'state', '--state', 'ESTABLISHED,RELATED',
            '-j', 'ACCEPT'
        ])
        
        # Drop excessive new connections
        self.run_command([
            self.iptables_cmd, '-A', chain_name,
            '-p', 'tcp', '--dport', str(mysql_port),
            '-m', 'state', '--state', 'NEW',
            '-j', 'DROP'
        ])
        
        # Jump to MySQL chain for MySQL traffic
        self._ensure_jump(chain_name, protocol='tcp', port=mysql_port)
        
        self.logger.info(f"MySQL protection applied: {rate_limit} rate limit, {max_connections} max conn/IP")
    
    def apply_wings_api_protection(self):
        """Apply protection for Pterodactyl Wings API"""
        wings_config = self.config.get('advanced.wings_api', {})
        
        if not wings_config.get('protection_enabled', True):
            return
        
        wings_port = wings_config.get('port', 8080)
        trusted_ips = wings_config.get('trusted_ips', ['127.0.0.1'])
        rate_limit = wings_config.get('rate_limit', '20/s')
        rate_limit_burst = wings_config.get('rate_limit_burst', 60)
        
        self.logger.info(f"Applying Wings API protection on port {wings_port}")
        
        chain_name = f"ANTIDDOS_WINGS_{wings_port}"
        self._ensure_chain(chain_name)
        
        # Allow trusted IPs
        for ip in trusted_ips:
            if ip and ip.strip():
                self.run_command([
                    self.iptables_cmd, '-A', chain_name,
                    '-s', ip.strip(),
                    '-j', 'ACCEPT'
                ])
        
        # Rate limit
        parts = rate_limit.split('/')
        if len(parts) == 2:
            self.run_command([
                self.iptables_cmd, '-A', chain_name,
                '-p', 'tcp', '--dport', str(wings_port),
                '-m', 'limit', '--limit', rate_limit, '--limit-burst', str(rate_limit_burst),
                '-j', 'ACCEPT'
            ])
        
        # Drop excessive traffic
        self.run_command([
            self.iptables_cmd, '-A', chain_name,
            '-p', 'tcp', '--dport', str(wings_port),
            '-j', 'DROP'
        ])
        
        # Jump to Wings chain
        self._ensure_jump(chain_name, protocol='tcp', port=wings_port)
        
        self.logger.info(f"Wings API protection applied: {rate_limit} rate limit")
    
    def apply_kernel_hardening(self):
        """Apply kernel-level protections"""
        self.logger.info("Applying kernel hardening")
        
        sysctl_settings = {
            # SYN cookies
            'net.ipv4.tcp_syncookies': '1',
            # Ignore ICMP redirects
            'net.ipv4.conf.all.accept_redirects': '0',
            'net.ipv6.conf.all.accept_redirects': '0',
            # Ignore source routed packets
            'net.ipv4.conf.all.accept_source_route': '0',
            'net.ipv6.conf.all.accept_source_route': '0',
            # Ignore ICMP echo requests (ping)
            'net.ipv4.icmp_echo_ignore_all': '0',
            # Enable reverse path filtering
            'net.ipv4.conf.all.rp_filter': '1',
            # Log martian packets
            'net.ipv4.conf.all.log_martians': '1',
            # Increase connection tracking table size
            'net.netfilter.nf_conntrack_max': str(self.config.get('advanced.max_conntrack_entries', 100000)),
            # TCP settings
            'net.ipv4.tcp_max_syn_backlog': '4096',
            'net.core.somaxconn': '4096',
            'net.ipv4.tcp_fin_timeout': '15',
            'net.ipv4.tcp_keepalive_time': '300',
        }
        
        for key, value in sysctl_settings.items():
            try:
                subprocess.run(
                    ['sysctl', '-w', f'{key}={value}'],
                    capture_output=True,
                    check=False
                )
            except Exception as e:
                self.logger.warning(f"Failed to set {key}: {e}")
    
    def apply_dos_filters(self):
        """Apply DoS protection filters - SOLO para tráfico NO-Pterodactyl"""
        self.logger.info("Applying DoS filters (Pterodactyl traffic bypassed)")
        
        # IMPORTANTE: Estos filtros NO afectan tráfico de Docker/Pterodactyl
        # porque las excepciones se aplican ANTES en la cadena INPUT
        
        # SYN flood protection - POR IP
        if self.config.get('dos_filter.syn_flood.enabled', True):
            threshold = self.config.get('dos_filter.syn_flood.threshold', 50)
            self.run_command([
                self.iptables_cmd, '-A', self.chain_name,
                '-p', 'tcp', '--syn',
                '-m', 'connlimit', '--connlimit-above', str(threshold), '--connlimit-mask', '32',
                '-j', 'REJECT', '--reject-with', 'tcp-reset'
            ])
            self.logger.info(f"SYN flood protection: max {threshold} SYN per IP")
        
        # UDP flood protection - MUY PERMISIVO para Minecraft
        # NOTA: El rate limiting de UDP se maneja mejor por servicio individual
        if self.config.get('dos_filter.udp_flood.enabled', True):
            threshold = self.config.get('dos_filter.udp_flood.threshold', 100)
            # Solo aplicar límite global extremadamente alto para evitar saturación del servidor
            # No limitar por IP porque Minecraft puede generar mucho tráfico legítimo
            self.run_command([
                self.iptables_cmd, '-A', self.chain_name,
                '-p', 'udp',
                '-m', 'limit', '--limit', f'{threshold * 10}/s', '--limit-burst', str(threshold * 20),
                '-j', 'ACCEPT'
            ])
            # NO DROP - permitir todo UDP que pase el límite global
            self.logger.info(f"UDP flood protection: global limit {threshold * 10}/s (permisivo para gaming)")
        
        # ICMP flood protection
        if self.config.get('dos_filter.icmp_flood.enabled', True):
            threshold = self.config.get('dos_filter.icmp_flood.threshold', 10)
            self.run_command([
                self.iptables_cmd, '-A', self.chain_name,
                '-p', 'icmp',
                '-m', 'limit', '--limit', f'{threshold}/s', '--limit-burst', str(threshold * 2),
                '-j', 'ACCEPT'
            ])
            self.run_command([
                self.iptables_cmd, '-A', self.chain_name,
                '-p', 'icmp',
                '-j', 'DROP'
            ])
        
        # Connection limit per IP - SOLO TCP
        if self.config.get('dos_filter.connection_limit.enabled', True):
            max_conn = self.config.get('dos_filter.connection_limit.max_connections', 50)
            self.run_command([
                self.iptables_cmd, '-A', self.chain_name,
                '-p', 'tcp',
                '-m', 'connlimit', '--connlimit-above', str(max_conn), '--connlimit-mask', '32',
                '-j', 'REJECT', '--reject-with', 'tcp-reset'
            ])
            self.logger.info(f"TCP connection limit: {max_conn} per IP")
    
    def apply_strict_limits(self):
        """Apply stricter rate limits during attack"""
        strict_cfg = self.config.get('advanced.strict_limits', {})
        if not strict_cfg.get('enabled', False):
            self.logger.debug("Strict limits disabled in config")
            return

        self.logger.info("Applying strict global rate limits")
        self._ensure_chain(self.strict_chain)

        burst_multiplier = max(1, int(strict_cfg.get('burst_multiplier', 2)))

        def add_limit(protocol: str, match_args: List[str], limit_value: int):
            limit_value = int(limit_value)
            if limit_value <= 0:
                return
            burst = max(limit_value * burst_multiplier, limit_value + 1)
            base_cmd = [self.iptables_cmd, '-A', self.strict_chain, '-p', protocol]
            base_cmd += match_args
            self.run_command(base_cmd + [
                '-m', 'limit', '--limit', f'{limit_value}/second',
                '--limit-burst', str(burst),
                '-j', 'RETURN'
            ])
            self.run_command([
                self.iptables_cmd, '-A', self.strict_chain,
                '-p', protocol
            ] + match_args + ['-j', 'DROP'])

        syn_limit = strict_cfg.get('syn_limit', 3000)
        add_limit('tcp', ['--syn'], syn_limit)

        udp_limit = strict_cfg.get('udp_limit', 5000)
        add_limit('udp', [], udp_limit)

        icmp_limit = strict_cfg.get('icmp_limit', 800)
        add_limit('icmp', [], icmp_limit)

        self._ensure_jump(self.strict_chain)
    
    def apply_normal_limits(self):
        """Restore normal rate limits"""
        self.logger.info("Restoring normal rate limits")
        self._remove_jump(self.strict_chain)
        self.run_command([self.iptables_cmd, '-F', self.strict_chain])
        self.run_command([self.iptables_cmd, '-X', self.strict_chain])
    
    def block_ip(self, ip: str, reason: str = ""):
        """Block an IP address for both host and Docker traffic"""
        self.logger.info(f"Blocking IP {ip}: {reason}")
        
        # Block in ANTIDDOS chain (affects both INPUT and FORWARD)
        # Add to beginning of chain for immediate effect
        self.run_command([
            self.iptables_cmd, '-I', self.chain_name, '1',
            '-s', ip,
            '-j', 'DROP'
        ])
        
        # Also explicitly block in FORWARD before Docker rules (belt and suspenders)
        self.run_command([
            self.iptables_cmd, '-I', 'FORWARD', '1',
            '-s', ip,
            '-j', 'DROP'
        ])
    
    def unblock_ip(self, ip: str):
        """Unblock an IP address from both host and Docker traffic"""
        self.logger.info(f"Unblocking IP {ip}")
        
        # Remove all rules matching this IP from ANTIDDOS chain
        while True:
            result = subprocess.run(
                [self.iptables_cmd, '-D', self.chain_name, '-s', ip, '-j', 'DROP'],
                capture_output=True,
                check=False
            )
            if result.returncode != 0:
                break
        
        # Also remove from FORWARD chain
        while True:
            result = subprocess.run(
                [self.iptables_cmd, '-D', 'FORWARD', '-s', ip, '-j', 'DROP'],
                capture_output=True,
                check=False
            )
            if result.returncode != 0:
                break
    
    def whitelist_ip(self, ip: str):
        """Add IP to whitelist (allow all traffic)"""
        self.logger.info(f"Whitelisting IP {ip}")
        
        # Add ACCEPT rule at the beginning
        self.run_command([
            self.iptables_cmd, '-I', self.chain_name, '1',
            '-s', ip,
            '-j', 'ACCEPT'
        ])
    
    def remove_from_whitelist(self, ip: str):
        """Remove IP from whitelist"""
        self.logger.info(f"Removing IP {ip} from whitelist")
        
        while True:
            result = subprocess.run(
                [self.iptables_cmd, '-D', self.chain_name, '-s', ip, '-j', 'ACCEPT'],
                capture_output=True,
                check=False
            )
            if result.returncode != 0:
                break
    
    def block_country(self, country_code: str, ip_ranges: List[str]):
        """Block all IPs from a country"""
        self.logger.info(f"Blocking country {country_code} ({len(ip_ranges)} ranges)")
        
        # Create country-specific chain
        chain_name = f"ANTIDDOS_{country_code}"
        self.run_command([self.iptables_cmd, '-N', chain_name])
        self.run_command([self.iptables_cmd, '-F', chain_name])
        
        # Add all IP ranges to the chain
        for ip_range in ip_ranges:
            self.run_command([
                self.iptables_cmd, '-A', chain_name,
                '-s', ip_range,
                '-j', 'DROP'
            ])
        
        # Jump to country chain from main chain
        self.run_command([
            self.iptables_cmd, '-A', self.chain_name,
            '-j', chain_name
        ])
    
    def unblock_country(self, country_code: str):
        """Unblock all IPs from a country"""
        self.logger.info(f"Unblocking country {country_code}")
        
        chain_name = f"ANTIDDOS_{country_code}"
        
        # Remove jump to country chain
        self.run_command([
            self.iptables_cmd, '-D', self.chain_name,
            '-j', chain_name
        ])
        
        # Flush and delete country chain
        self.run_command([self.iptables_cmd, '-F', chain_name])
        self.run_command([self.iptables_cmd, '-X', chain_name])
    
    def cleanup(self):
        """Remove all firewall rules - SAFE cleanup that preserves Docker/Pterodactyl"""
        self.logger.info(f"Cleaning up firewall rules using {self.iptables_cmd} (preserving Docker/Pterodactyl)")
        
        cleanup_success = True
        
        # Remove jump to our chain from INPUT
        removed_input = 0
        while True:
            result = subprocess.run(
                [self.iptables_cmd, '-D', 'INPUT', '-j', self.chain_name],
                capture_output=True,
                text=True,
                check=False
            )
            if result.returncode != 0:
                break
            removed_input += 1
        
        if removed_input > 0:
            self.logger.info(f"Removed {removed_input} jump(s) from INPUT chain")
        
        # Remove jump to our chain from FORWARD
        removed_forward = 0
        while True:
            result = subprocess.run(
                [self.iptables_cmd, '-D', 'FORWARD', '-j', self.chain_name],
                capture_output=True,
                text=True,
                check=False
            )
            if result.returncode != 0:
                break
            removed_forward += 1
        
        if removed_forward > 0:
            self.logger.info(f"Removed {removed_forward} jump(s) from FORWARD chain")
        
        # Remove jump from OUTPUT (just in case)
        removed_output = 0
        while True:
            result = subprocess.run(
                [self.iptables_cmd, '-D', 'OUTPUT', '-j', self.chain_name],
                capture_output=True,
                text=True,
                check=False
            )
            if result.returncode != 0:
                break
            removed_output += 1
        
        if removed_output > 0:
            self.logger.info(f"Removed {removed_output} jump(s) from OUTPUT chain")
        
        # Flush and delete our main chain
        result = subprocess.run(
            [self.iptables_cmd, '-F', self.chain_name],
            capture_output=True,
            text=True,
            check=False
        )
        if result.returncode == 0:
            self.logger.info(f"Flushed chain {self.chain_name}")
        else:
            self.logger.debug(f"Chain {self.chain_name} flush: {result.stderr.strip()}")
        
        result = subprocess.run(
            [self.iptables_cmd, '-X', self.chain_name],
            capture_output=True,
            text=True,
            check=False
        )
        if result.returncode == 0:
            self.logger.info(f"Deleted chain {self.chain_name}")
        else:
            self.logger.warning(f"Failed to delete chain {self.chain_name}: {result.stderr.strip()}")
            cleanup_success = False
        
        # Clean up strict chain
        subprocess.run([self.iptables_cmd, '-F', self.strict_chain], capture_output=True, check=False)
        subprocess.run([self.iptables_cmd, '-X', self.strict_chain], capture_output=True, check=False)
        
        # Also clean up any per-port chains we created
        chain_list_result = subprocess.run(
            [self.iptables_cmd, '-S'],  # Use -S instead of -L for better parsing
            capture_output=True,
            text=True,
            check=False
        )
        
        chains_to_delete = []
        if chain_list_result.returncode == 0:
            for line in chain_list_result.stdout.split('\n'):
                if f'-N {self.chain_name}_' in line or f'-N {self.chain_name}' in line:
                    # Extract chain name
                    parts = line.split()
                    if len(parts) >= 2 and parts[0] == '-N':
                        chain = parts[1]
                        if chain != self.chain_name and chain.startswith(self.chain_name):
                            chains_to_delete.append(chain)
        
        for chain in chains_to_delete:
            self.logger.info(f"Cleaning up additional chain: {chain}")
            subprocess.run([self.iptables_cmd, '-F', chain], capture_output=True, check=False)
            subprocess.run([self.iptables_cmd, '-X', chain], capture_output=True, check=False)
        
        # IMPORTANT: DO NOT touch DOCKER chains, NAT table, or base FORWARD chain
        # Docker and Pterodactyl Wings manage these automatically
        
        if cleanup_success:
            self.logger.info("✓ Cleanup completed successfully - Docker/Pterodactyl rules preserved")
        else:
            self.logger.warning("⚠ Cleanup completed with warnings - verify manually")
        
        return cleanup_success
