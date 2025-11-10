"""
Main monitoring daemon for Anti-DDoS system
Monitors bandwidth, PPS, and applies filters dynamically
"""

import time
import psutil
import logging
import signal
import sys
from typing import Dict, List, Tuple
from datetime import datetime, timedelta
from collections import defaultdict, deque

from .config import Config
from .firewall import FirewallManager
from .geoip import GeoIPManager
from .blacklist import BlacklistManager
from .notifications import DiscordNotifier


class BandwidthMonitor:
    """Monitor network bandwidth and packets per second"""
    
    def __init__(self, interface: str, window_seconds: int = 10):
        self.interface = interface
        self.window_seconds = window_seconds
        self.samples = deque(maxlen=window_seconds)
        self.last_stats = None
        self.logger = logging.getLogger(__name__)
    
    def get_stats(self) -> Tuple[float, float, int, int]:
        """
        Get current network statistics
        Returns: (mbps_in, mbps_out, pps_in, pps_out)
        """
        try:
            stats = psutil.net_io_counters(pernic=True).get(self.interface)
            if not stats:
                self.logger.warning(f"Interface {self.interface} not found")
                return (0.0, 0.0, 0, 0)
            
            current_time = time.time()
            current_stats = {
                'time': current_time,
                'bytes_sent': stats.bytes_sent,
                'bytes_recv': stats.bytes_recv,
                'packets_sent': stats.packets_sent,
                'packets_recv': stats.packets_recv
            }
            
            if self.last_stats:
                time_delta = current_time - self.last_stats['time']
                if time_delta > 0:
                    bytes_sent_delta = current_stats['bytes_sent'] - self.last_stats['bytes_sent']
                    bytes_recv_delta = current_stats['bytes_recv'] - self.last_stats['bytes_recv']
                    packets_sent_delta = current_stats['packets_sent'] - self.last_stats['packets_sent']
                    packets_recv_delta = current_stats['packets_recv'] - self.last_stats['packets_recv']
                    
                    mbps_out = (bytes_sent_delta * 8) / (time_delta * 1_000_000)
                    mbps_in = (bytes_recv_delta * 8) / (time_delta * 1_000_000)
                    pps_out = int(packets_sent_delta / time_delta)
                    pps_in = int(packets_recv_delta / time_delta)
                    
                    self.samples.append({
                        'mbps_in': mbps_in,
                        'mbps_out': mbps_out,
                        'pps_in': pps_in,
                        'pps_out': pps_out
                    })
            
            self.last_stats = current_stats
            
            # Calculate average over window
            if self.samples:
                avg_mbps_in = sum(s['mbps_in'] for s in self.samples) / len(self.samples)
                avg_mbps_out = sum(s['mbps_out'] for s in self.samples) / len(self.samples)
                avg_pps_in = int(sum(s['pps_in'] for s in self.samples) / len(self.samples))
                avg_pps_out = int(sum(s['pps_out'] for s in self.samples) / len(self.samples))
                return (avg_mbps_in, avg_mbps_out, avg_pps_in, avg_pps_out)
            
            return (0.0, 0.0, 0, 0)
            
        except Exception as e:
            self.logger.error(f"Error getting network stats: {e}")
            return (0.0, 0.0, 0, 0)


class ConnectionTracker:
    """Track connections per IP for DoS detection"""
    
    def __init__(self):
        self.connections = defaultdict(lambda: {'count': 0, 'last_seen': datetime.now()})
        self.logger = logging.getLogger(__name__)
    
    def track(self, ip: str) -> int:
        """Track a connection from an IP, return current count"""
        now = datetime.now()
        self.connections[ip]['count'] += 1
        self.connections[ip]['last_seen'] = now
        return self.connections[ip]['count']
    
    def get_count(self, ip: str, time_window: int = 1) -> int:
        """Get connection count for IP within time window (seconds)"""
        now = datetime.now()
        if ip in self.connections:
            last_seen = self.connections[ip]['last_seen']
            if (now - last_seen).total_seconds() <= time_window:
                return self.connections[ip]['count']
        return 0
    
    def cleanup(self, max_age: int = 60):
        """Remove old entries"""
        now = datetime.now()
        to_remove = []
        for ip, data in self.connections.items():
            if (now - data['last_seen']).total_seconds() > max_age:
                to_remove.append(ip)
        
        for ip in to_remove:
            del self.connections[ip]


class AntiDDoSMonitor:
    """Main Anti-DDoS monitoring daemon"""
    
    def __init__(self, config_path: str = "/etc/antiddos/config.yaml"):
        self.config = Config(config_path)
        self.setup_logging()
        
        self.logger = logging.getLogger(__name__)
        self.logger.info("Initializing Anti-DDoS Monitor")
        
        self.firewall = FirewallManager(self.config)
        self.geoip = GeoIPManager(self.config)
        self.discord = DiscordNotifier(self.config)
        self.blacklist = BlacklistManager(self.config, self.discord)
        
        interface = self.config.get('bandwidth.interface', 'eth0')
        window = self.config.get('bandwidth.window_seconds', 10)
        self.bandwidth_monitor = BandwidthMonitor(interface, window)
        
        self.connection_tracker = ConnectionTracker()
        self.running = False
        self.mitigation_active = False
        self.attack_start_time = None
        self.blocked_ips_in_attack = []
        
        # Setup signal handlers
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
    
    def setup_logging(self):
        """Setup logging configuration"""
        log_level = self.config.get('general.log_level', 'INFO')
        log_file = self.config.get('general.log_file', '/var/log/antiddos/antiddos.log')
        
        # Create log directory if it doesn't exist
        import os
        os.makedirs(os.path.dirname(log_file), exist_ok=True)
        
        logging.basicConfig(
            level=getattr(logging, log_level),
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
    
    def signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.stop()
    
    def start(self):
        """Start the monitoring daemon"""
        self.logger.info("Starting Anti-DDoS Monitor")
        self.running = True
        
        # Initialize firewall rules
        self.firewall.initialize()
        
        # Load blacklist
        self.blacklist.load()
        
        check_interval = self.config.get('general.check_interval', 5)
        
        while self.running:
            try:
                self.check_bandwidth()
                self.check_dos_attacks()
                self.connection_tracker.cleanup()
                time.sleep(check_interval)
            except Exception as e:
                self.logger.error(f"Error in monitoring loop: {e}", exc_info=True)
                time.sleep(check_interval)
    
    def check_bandwidth(self):
        """Check bandwidth and apply mitigation if needed"""
        if not self.config.get('bandwidth.enabled', True):
            return
        
        mbps_in, mbps_out, pps_in, pps_out = self.bandwidth_monitor.get_stats()
        
        threshold_mbps = self.config.get('bandwidth.threshold_mbps', 1000)
        threshold_pps = self.config.get('bandwidth.threshold_pps', 100000)
        
        total_mbps = mbps_in + mbps_out
        total_pps = pps_in + pps_out
        
        # Log current stats
        if total_mbps > 10 or total_pps > 1000:  # Only log significant traffic
            self.logger.debug(
                f"Traffic: {total_mbps:.2f} Mbps ({mbps_in:.2f} in, {mbps_out:.2f} out), "
                f"{total_pps} PPS ({pps_in} in, {pps_out} out)"
            )
        
        # Check if mitigation should be triggered
        should_mitigate = (
            total_mbps > threshold_mbps or
            total_pps > threshold_pps
        )
        
        if should_mitigate and not self.mitigation_active:
            self.logger.warning(
                f"Bandwidth threshold exceeded! {total_mbps:.2f} Mbps / {total_pps} PPS"
            )
            self.activate_mitigation()
        elif not should_mitigate and self.mitigation_active:
            self.logger.info("Traffic normalized, deactivating mitigation")
            self.deactivate_mitigation()
    
    def check_dos_attacks(self):
        """Check for DoS attack patterns"""
        if not self.config.get('dos_filter.enabled', True):
            return
        
        # This would integrate with netfilter/conntrack to get real connection data
        # For now, this is a placeholder for the structure
        pass
    
    def activate_mitigation(self):
        """Activate DDoS mitigation measures"""
        self.mitigation_active = True
        self.attack_start_time = datetime.now()
        self.blocked_ips_in_attack = []
        
        # Get current traffic stats
        mbps_in, mbps_out, pps_in, pps_out = self.bandwidth_monitor.get_stats()
        total_mbps = mbps_in + mbps_out
        total_pps = pps_in + pps_out
        
        self.logger.warning(f"Activating DDoS mitigation - Traffic: {total_mbps:.2f} Mbps, {total_pps} PPS")
        
        # Notify Discord about attack
        self.discord.notify_attack_detected(total_mbps, total_pps)
        
        actions = []
        
        # Apply country filter if configured
        if self.config.get('country_filter.trigger_on_bandwidth', False):
            self.logger.info("Applying country-based filtering")
            self.geoip.apply_country_filter()
            actions.append("Filtrado por país activado")
        
        # Apply stricter rate limits
        self.firewall.apply_strict_limits()
        actions.append("Límites de tasa estrictos aplicados")
        
        # Notify about mitigation activation
        self.discord.notify_mitigation_activated(
            f"Tráfico excesivo detectado: {total_mbps:.2f} Mbps",
            actions
        )
    
    def deactivate_mitigation(self):
        """Deactivate DDoS mitigation measures"""
        self.mitigation_active = False
        
        # Calculate attack duration
        if self.attack_start_time:
            duration = datetime.now() - self.attack_start_time
            duration_str = str(duration).split('.')[0]  # Remove microseconds
            self.logger.info(f"Deactivating DDoS mitigation - Attack duration: {duration_str}")
        else:
            self.logger.info("Deactivating DDoS mitigation")
        
        # Remove country filter if it was applied
        if self.config.get('country_filter.trigger_on_bandwidth', False):
            self.geoip.remove_country_filter()
        
        # Restore normal rate limits
        self.firewall.apply_normal_limits()
        
        # Notify Discord about mitigation deactivation
        self.discord.notify_mitigation_deactivated()
        
        # If we blocked IPs during the attack, notify about them
        if len(self.blocked_ips_in_attack) > 0:
            self.discord.notify_bulk_blocks(
                self.blocked_ips_in_attack,
                "IPs bloqueadas durante el ataque DDoS"
            )
        
        # Reset attack tracking
        self.attack_start_time = None
        self.blocked_ips_in_attack = []
    
    def send_notification(self, message: str):
        """Send notification via configured channels"""
        if not self.config.get('notifications.enabled', False):
            return
        
        self.logger.info(f"Notification: {message}")
        # Email and webhook notifications would be implemented here
    
    def stop(self):
        """Stop the monitoring daemon"""
        self.running = False
        self.logger.info("Anti-DDoS Monitor stopped")
        sys.exit(0)


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Anti-DDoS Monitoring Daemon')
    parser.add_argument('-c', '--config', default='/etc/antiddos/config.yaml',
                        help='Path to configuration file')
    args = parser.parse_args()
    
    monitor = AntiDDoSMonitor(args.config)
    monitor.start()


if __name__ == '__main__':
    main()
