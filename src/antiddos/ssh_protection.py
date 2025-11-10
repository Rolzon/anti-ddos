"""
SSH Protection - Failed attempt monitoring and banning (Fail2ban-like)
"""

import re
import logging
import time
import signal
import sys
from datetime import datetime, timedelta
from collections import defaultdict
from typing import Dict, List
from pathlib import Path

from .notifications import DiscordNotifier


class SSHProtection:
    """Monitor SSH failed attempts and ban offending IPs"""
    
    def __init__(self, config):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.discord = DiscordNotifier(config)
        
        self.log_file = self.config.get('ssh_protection.log_file', '/var/log/auth.log')
        self.max_attempts = self.config.get('ssh_protection.max_attempts', 5)
        self.ban_time = self.config.get('ssh_protection.ban_time', 3600)
        self.find_time = self.config.get('ssh_protection.find_time', 600)
        
        # Track failed attempts: IP -> list of timestamps
        self.failed_attempts: Dict[str, List[datetime]] = defaultdict(list)
        self.banned_ips: Dict[str, datetime] = {}  # IP -> ban expiry time
        
        # Regex patterns for SSH failed attempts
        self.patterns = [
            # Failed password
            re.compile(r'Failed password for .+ from (\d+\.\d+\.\d+\.\d+)'),
            # Invalid user
            re.compile(r'Invalid user .+ from (\d+\.\d+\.\d+\.\d+)'),
            # Connection closed by authenticating user
            re.compile(r'Connection closed by authenticating user .+ (\d+\.\d+\.\d+\.\d+)'),
            # Did not receive identification string
            re.compile(r'Did not receive identification string from (\d+\.\d+\.\d+\.\d+)'),
            # Connection reset by peer
            re.compile(r'Connection reset by (\d+\.\d+\.\d+\.\d+)'),
            # Maximum authentication attempts exceeded
            re.compile(r'maximum authentication attempts exceeded for .+ from (\d+\.\d+\.\d+\.\d+)'),
        ]
        
        self.running = False
        self.last_position = 0
        
        # Setup signal handlers
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
    
    def signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.stop()
    
    def start(self):
        """Start SSH protection monitoring"""
        if not self.config.get('ssh_protection.enabled', True):
            self.logger.info("SSH protection is disabled")
            return
        
        self.logger.info("Starting SSH protection")
        self.running = True
        
        # Get initial file position
        if Path(self.log_file).exists():
            self.last_position = Path(self.log_file).stat().st_size
        
        while self.running:
            try:
                self.monitor_log()
                self.cleanup_old_attempts()
                self.check_expired_bans()
                time.sleep(1)
            except Exception as e:
                self.logger.error(f"Error in SSH protection loop: {e}", exc_info=True)
                time.sleep(5)
    
    def monitor_log(self):
        """Monitor auth log for failed SSH attempts"""
        if not Path(self.log_file).exists():
            return
        
        try:
            with open(self.log_file, 'r') as f:
                # Seek to last position
                f.seek(self.last_position)
                
                # Read new lines
                for line in f:
                    self.process_log_line(line)
                
                # Update position
                self.last_position = f.tell()
        
        except Exception as e:
            self.logger.error(f"Error reading log file: {e}")
    
    def process_log_line(self, line: str):
        """Process a single log line"""
        # Try each pattern
        for pattern in self.patterns:
            match = pattern.search(line)
            if match:
                ip = match.group(1)
                self.record_failed_attempt(ip)
                break
    
    def record_failed_attempt(self, ip: str):
        """Record a failed SSH attempt"""
        # Check if IP is whitelisted
        from .blacklist import BlacklistManager
        blacklist_mgr = BlacklistManager(self.config)
        
        if blacklist_mgr.is_whitelisted(ip):
            self.logger.debug(f"Ignoring failed attempt from whitelisted IP {ip}")
            return
        
        # Check if already banned
        if ip in self.banned_ips:
            return
        
        now = datetime.now()
        self.failed_attempts[ip].append(now)
        
        # Count recent attempts
        recent_attempts = [
            t for t in self.failed_attempts[ip]
            if (now - t).total_seconds() <= self.find_time
        ]
        
        self.logger.info(
            f"Failed SSH attempt from {ip} "
            f"({len(recent_attempts)}/{self.max_attempts} in {self.find_time}s)"
        )
        
        # Check if threshold exceeded
        if len(recent_attempts) >= self.max_attempts:
            self.ban_ip(ip)
    
    def ban_ip(self, ip: str):
        """Ban an IP address"""
        attempts_count = len(self.failed_attempts[ip])
        self.logger.warning(f"Banning IP {ip} for {self.ban_time} seconds due to failed SSH attempts")
        
        # Show banner
        self.show_banner(ip)
        
        # Send Discord notification about SSH attack
        self.discord.notify_ssh_attack(ip, attempts_count)
        
        # Add to blacklist
        from .blacklist import BlacklistManager
        blacklist_mgr = BlacklistManager(self.config, self.discord)
        blacklist_mgr.add_to_blacklist(
            ip,
            reason=f"SSH failed attempts ({attempts_count} attempts)",
            duration=self.ban_time
        )
        
        # Track ban expiry
        self.banned_ips[ip] = datetime.now() + timedelta(seconds=self.ban_time)
        
        # Clear failed attempts for this IP
        self.failed_attempts[ip] = []
    
    def show_banner(self, ip: str):
        """Show warning banner for banned IP"""
        banner = self.config.get('ssh_protection.banner', '')
        if banner:
            self.logger.warning(f"\n{banner}\nBanned IP: {ip}\n")
    
    def cleanup_old_attempts(self):
        """Remove old failed attempt records"""
        now = datetime.now()
        cutoff = now - timedelta(seconds=self.find_time * 2)
        
        for ip in list(self.failed_attempts.keys()):
            # Remove old timestamps
            self.failed_attempts[ip] = [
                t for t in self.failed_attempts[ip]
                if t > cutoff
            ]
            
            # Remove IP if no recent attempts
            if not self.failed_attempts[ip]:
                del self.failed_attempts[ip]
    
    def check_expired_bans(self):
        """Check for expired bans and unban IPs"""
        now = datetime.now()
        expired = []
        
        for ip, expiry in self.banned_ips.items():
            if now >= expiry:
                expired.append(ip)
        
        for ip in expired:
            self.logger.info(f"SSH ban expired for {ip}")
            del self.banned_ips[ip]
            
            # Remove from blacklist
            from .blacklist import BlacklistManager
            blacklist_mgr = BlacklistManager(self.config)
            blacklist_mgr.remove_from_blacklist(ip)
    
    def stop(self):
        """Stop SSH protection"""
        self.running = False
        self.logger.info("SSH protection stopped")
        sys.exit(0)


def main():
    """Main entry point"""
    import argparse
    from .config import Config
    
    parser = argparse.ArgumentParser(description='SSH Protection Service')
    parser.add_argument('-c', '--config', default='/etc/antiddos/config.yaml',
                        help='Path to configuration file')
    args = parser.parse_args()
    
    # Setup logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('/var/log/antiddos/ssh-protection.log'),
            logging.StreamHandler(sys.stdout)
        ]
    )
    
    config = Config(args.config)
    ssh_protection = SSHProtection(config)
    ssh_protection.start()


if __name__ == '__main__':
    main()
