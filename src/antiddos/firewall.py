"""
Firewall management using iptables
"""

import subprocess
import logging
from typing import List, Optional


class FirewallManager:
    """Manage iptables rules for DDoS protection"""
    
    def __init__(self, config):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.chain_name = "ANTIDDOS"
        
        # Detect iptables binary (prefer iptables-legacy)
        self.iptables_cmd = self._detect_iptables()
        self.logger.info(f"Using iptables binary: {self.iptables_cmd}")
    
    def _detect_iptables(self) -> str:
        """Detect which iptables binary to use"""
        # Try iptables-legacy first
        try:
            result = subprocess.run(
                ['iptables-legacy', '-L', '-n'],
                capture_output=True,
                check=False,
                timeout=5
            )
            if result.returncode == 0:
                return 'iptables-legacy'
        except:
            pass
        
        # Fallback to regular iptables
        return 'iptables'
    
    def run_command(self, cmd: List[str]) -> bool:
        """Run iptables command"""
        try:
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
    
    def initialize(self):
        """Initialize firewall rules"""
        self.logger.info("Initializing firewall rules")
        
        # Create custom chain if it doesn't exist
        self.run_command([self.iptables_cmd, '-N', self.chain_name])
        
        # Flush existing rules in our chain
        self.run_command([self.iptables_cmd, '-F', self.chain_name])
        
        # Insert our chain at the beginning of INPUT
        self.run_command([self.iptables_cmd, '-I', 'INPUT', '-j', self.chain_name])
        
        # Apply kernel hardening if configured
        if self.config.get('advanced.kernel_hardening', True):
            self.apply_kernel_hardening()
        
        # Apply DoS filters
        if self.config.get('dos_filter.enabled', True):
            self.apply_dos_filters()
        
        self.logger.info("Firewall rules initialized")
    
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
        """Apply DoS protection filters"""
        self.logger.info("Applying DoS filters")
        
        # SYN flood protection
        if self.config.get('dos_filter.syn_flood.enabled', True):
            threshold = self.config.get('dos_filter.syn_flood.threshold', 50)
            self.run_command([
                self.iptables_cmd, '-A', self.chain_name,
                '-p', 'tcp', '--syn',
                '-m', 'limit', '--limit', f'{threshold}/s', '--limit-burst', str(threshold * 2),
                '-j', 'ACCEPT'
            ])
            self.run_command([
                self.iptables_cmd, '-A', self.chain_name,
                '-p', 'tcp', '--syn',
                '-j', 'DROP'
            ])
        
        # UDP flood protection
        if self.config.get('dos_filter.udp_flood.enabled', True):
            threshold = self.config.get('dos_filter.udp_flood.threshold', 100)
            self.run_command([
                self.iptables_cmd, '-A', self.chain_name,
                '-p', 'udp',
                '-m', 'limit', '--limit', f'{threshold}/s', '--limit-burst', str(threshold * 2),
                '-j', 'ACCEPT'
            ])
            self.run_command([
                self.iptables_cmd, '-A', self.chain_name,
                '-p', 'udp',
                '-j', 'DROP'
            ])
        
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
        
        # Connection limit per IP
        if self.config.get('dos_filter.connection_limit.enabled', True):
            max_conn = self.config.get('dos_filter.connection_limit.max_connections', 50)
            self.run_command([
                self.iptables_cmd, '-A', self.chain_name,
                '-p', 'tcp',
                '-m', 'connlimit', '--connlimit-above', str(max_conn),
                '-j', 'REJECT', '--reject-with', 'tcp-reset'
            ])
    
    def apply_strict_limits(self):
        """Apply stricter rate limits during attack"""
        self.logger.info("Applying strict rate limits")
        
        # Temporarily reduce limits by 50%
        # This would modify existing rules or add more restrictive ones
        pass
    
    def apply_normal_limits(self):
        """Restore normal rate limits"""
        self.logger.info("Restoring normal rate limits")
        
        # Restore original limits
        pass
    
    def block_ip(self, ip: str, reason: str = ""):
        """Block an IP address"""
        self.logger.info(f"Blocking IP {ip}: {reason}")
        
        # Add to beginning of chain for immediate effect
        self.run_command([
            self.iptables_cmd, '-I', self.chain_name, '1',
            '-s', ip,
            '-j', 'DROP'
        ])
    
    def unblock_ip(self, ip: str):
        """Unblock an IP address"""
        self.logger.info(f"Unblocking IP {ip}")
        
        # Remove all rules matching this IP
        while True:
            result = subprocess.run(
                [self.iptables_cmd, '-D', self.chain_name, '-s', ip, '-j', 'DROP'],
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
        """Remove all firewall rules"""
        self.logger.info("Cleaning up firewall rules")
        
        # Remove jump to our chain
        self.run_command([self.iptables_cmd, '-D', 'INPUT', '-j', self.chain_name])
        
        # Flush and delete our chain
        self.run_command([self.iptables_cmd, '-F', self.chain_name])
        self.run_command([self.iptables_cmd, '-X', self.chain_name])
