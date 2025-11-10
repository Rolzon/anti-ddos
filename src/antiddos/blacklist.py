"""
Blacklist and whitelist management
"""

import logging
import os
from typing import Set, Optional
from datetime import datetime, timedelta
from pathlib import Path


class BlacklistManager:
    """Manage IP blacklist and whitelist"""
    
    def __init__(self, config, discord_notifier=None):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.discord = discord_notifier
        
        self.blacklist_file = self.config.get('blacklist.file', '/etc/antiddos/blacklist.txt')
        self.whitelist_file = self.config.get('whitelist.file', '/etc/antiddos/whitelist.txt')
        
        self.blacklist: Set[str] = set()
        self.whitelist: Set[str] = set()
        self.temp_bans = {}  # IP -> expiry time
    
    def load(self):
        """Load blacklist and whitelist from files"""
        self.load_blacklist()
        self.load_whitelist()
        self.apply_all()
    
    def load_blacklist(self):
        """Load blacklist from file"""
        if os.path.exists(self.blacklist_file):
            try:
                with open(self.blacklist_file, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith('#'):
                            self.blacklist.add(line)
                self.logger.info(f"Loaded {len(self.blacklist)} IPs from blacklist")
            except Exception as e:
                self.logger.error(f"Failed to load blacklist: {e}")
        else:
            self.logger.info("Blacklist file not found, starting with empty blacklist")
            # Create empty file
            os.makedirs(os.path.dirname(self.blacklist_file), exist_ok=True)
            Path(self.blacklist_file).touch()
    
    def load_whitelist(self):
        """Load whitelist from file"""
        # Add configured whitelist IPs
        configured_ips = self.config.get('whitelist.ips', [])
        self.whitelist.update(configured_ips)
        
        if os.path.exists(self.whitelist_file):
            try:
                with open(self.whitelist_file, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith('#'):
                            self.whitelist.add(line)
                self.logger.info(f"Loaded {len(self.whitelist)} IPs from whitelist")
            except Exception as e:
                self.logger.error(f"Failed to load whitelist: {e}")
        else:
            self.logger.info("Whitelist file not found, starting with configured IPs only")
            # Create file with configured IPs
            os.makedirs(os.path.dirname(self.whitelist_file), exist_ok=True)
            self.save_whitelist()
    
    def save_blacklist(self):
        """Save blacklist to file"""
        if not self.config.get('blacklist.auto_save', True):
            return
        
        try:
            os.makedirs(os.path.dirname(self.blacklist_file), exist_ok=True)
            with open(self.blacklist_file, 'w') as f:
                f.write("# Anti-DDoS Blacklist\n")
                f.write(f"# Generated: {datetime.now().isoformat()}\n")
                f.write("# One IP per line\n\n")
                for ip in sorted(self.blacklist):
                    f.write(f"{ip}\n")
            self.logger.debug("Blacklist saved")
        except Exception as e:
            self.logger.error(f"Failed to save blacklist: {e}")
    
    def save_whitelist(self):
        """Save whitelist to file"""
        try:
            os.makedirs(os.path.dirname(self.whitelist_file), exist_ok=True)
            with open(self.whitelist_file, 'w') as f:
                f.write("# Anti-DDoS Whitelist\n")
                f.write(f"# Generated: {datetime.now().isoformat()}\n")
                f.write("# One IP per line\n\n")
                for ip in sorted(self.whitelist):
                    f.write(f"{ip}\n")
            self.logger.debug("Whitelist saved")
        except Exception as e:
            self.logger.error(f"Failed to save whitelist: {e}")
    
    def apply_all(self):
        """Apply all blacklist and whitelist rules to firewall"""
        from .firewall import FirewallManager
        firewall = FirewallManager(self.config)
        
        # Apply whitelist first (takes precedence)
        if self.config.get('whitelist.enabled', True):
            for ip in self.whitelist:
                firewall.whitelist_ip(ip)
        
        # Apply blacklist
        if self.config.get('blacklist.enabled', True):
            for ip in self.blacklist:
                firewall.block_ip(ip, "Blacklisted")
    
    def add_to_blacklist(self, ip: str, reason: str = "", duration: Optional[int] = None):
        """
        Add IP to blacklist
        
        Args:
            ip: IP address to block
            reason: Reason for blocking
            duration: Duration in seconds (None for permanent)
        """
        if ip in self.whitelist:
            self.logger.warning(f"Cannot blacklist {ip}: IP is whitelisted")
            return False
        
        if ip in self.blacklist:
            self.logger.info(f"IP {ip} already in blacklist")
            return True
        
        self.logger.info(f"Adding {ip} to blacklist: {reason}")
        
        if duration:
            # Temporary ban
            expiry = datetime.now() + timedelta(seconds=duration)
            self.temp_bans[ip] = expiry
            self.logger.info(f"Temporary ban until {expiry.isoformat()}")
        else:
            # Permanent ban
            self.blacklist.add(ip)
            self.save_blacklist()
        
        # Apply to firewall
        from .firewall import FirewallManager
        firewall = FirewallManager(self.config)
        firewall.block_ip(ip, reason)
        
        # Send Discord notification
        if self.discord:
            self.discord.notify_ip_blocked(ip, reason, duration)
        
        return True
    
    def remove_from_blacklist(self, ip: str):
        """Remove IP from blacklist"""
        if ip not in self.blacklist and ip not in self.temp_bans:
            self.logger.info(f"IP {ip} not in blacklist")
            return False
        
        self.logger.info(f"Removing {ip} from blacklist")
        
        self.blacklist.discard(ip)
        self.temp_bans.pop(ip, None)
        self.save_blacklist()
        
        # Remove from firewall
        from .firewall import FirewallManager
        firewall = FirewallManager(self.config)
        firewall.unblock_ip(ip)
        
        # Send Discord notification
        if self.discord:
            self.discord.notify_ip_unblocked(ip, "Ban expirado o removido manualmente")
        
        return True
    
    def add_to_whitelist(self, ip: str):
        """Add IP to whitelist"""
        if ip in self.whitelist:
            self.logger.info(f"IP {ip} already in whitelist")
            return True
        
        self.logger.info(f"Adding {ip} to whitelist")
        
        # Remove from blacklist if present
        if ip in self.blacklist:
            self.remove_from_blacklist(ip)
        
        self.whitelist.add(ip)
        self.save_whitelist()
        
        # Apply to firewall
        from .firewall import FirewallManager
        firewall = FirewallManager(self.config)
        firewall.whitelist_ip(ip)
        
        return True
    
    def remove_from_whitelist(self, ip: str):
        """Remove IP from whitelist"""
        if ip not in self.whitelist:
            self.logger.info(f"IP {ip} not in whitelist")
            return False
        
        self.logger.info(f"Removing {ip} from whitelist")
        
        self.whitelist.discard(ip)
        self.save_whitelist()
        
        # Remove from firewall
        from .firewall import FirewallManager
        firewall = FirewallManager(self.config)
        firewall.remove_whitelist_ip(ip)
        
        return True
    
    def is_blacklisted(self, ip: str) -> bool:
        """Check if IP is blacklisted"""
        return ip in self.blacklist or ip in self.temp_bans
    
    def is_whitelisted(self, ip: str) -> bool:
        """Check if IP is whitelisted"""
        return ip in self.whitelist
    
    def cleanup_expired_bans(self):
        """Remove expired temporary bans"""
        now = datetime.now()
        expired = []
        
        for ip, expiry in self.temp_bans.items():
            if now >= expiry:
                expired.append(ip)
        
        for ip in expired:
            self.logger.info(f"Temporary ban expired for {ip}")
            self.remove_from_blacklist(ip)
    
    def get_blacklist(self) -> Set[str]:
        """Get all blacklisted IPs"""
        return self.blacklist.union(set(self.temp_bans.keys()))
    
    def get_whitelist(self) -> Set[str]:
        """Get all whitelisted IPs"""
        return self.whitelist
