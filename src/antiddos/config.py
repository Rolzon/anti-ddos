"""
Configuration management for Anti-DDoS system
"""

import yaml
import os
from typing import Dict, Any
from pathlib import Path


class Config:
    """Configuration manager with hot-reload support"""
    
    def __init__(self, config_path: str = "/etc/antiddos/config.yaml"):
        self.config_path = config_path
        self.config: Dict[str, Any] = {}
        self.load()
    
    def load(self) -> None:
        """Load configuration from YAML file"""
        try:
            with open(self.config_path, 'r') as f:
                self.config = yaml.safe_load(f)
        except FileNotFoundError:
            # Use default config if file doesn't exist
            self.config = self._get_default_config()
            print(f"Warning: Config file not found at {self.config_path}, using defaults")
        except yaml.YAMLError as e:
            print(f"Error parsing config file: {e}")
            raise
    
    def reload(self) -> None:
        """Reload configuration from file"""
        self.load()
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value by key (supports nested keys with dot notation)"""
        keys = key.split('.')
        value = self.config
        
        for k in keys:
            if isinstance(value, dict):
                value = value.get(k)
                if value is None:
                    return default
            else:
                return default
        
        return value
    
    def set(self, key: str, value: Any) -> None:
        """Set configuration value by key (supports nested keys with dot notation)"""
        keys = key.split('.')
        config = self.config
        
        for k in keys[:-1]:
            if k not in config:
                config[k] = {}
            config = config[k]
        
        config[keys[-1]] = value
    
    def save(self) -> None:
        """Save configuration to file"""
        try:
            # Create directory if it doesn't exist
            os.makedirs(os.path.dirname(self.config_path), exist_ok=True)
            
            with open(self.config_path, 'w') as f:
                yaml.dump(self.config, f, default_flow_style=False)
        except Exception as e:
            print(f"Error saving config file: {e}")
            raise
    
    def _get_default_config(self) -> Dict[str, Any]:
        """Return default configuration"""
        return {
            'general': {
                'log_level': 'INFO',
                'log_file': '/var/log/antiddos/antiddos.log',
                'pid_file': '/var/run/antiddos.pid',
                'check_interval': 5
            },
            'bandwidth': {
                'enabled': True,
                'interface': 'eth0',
                'threshold_mbps': 1000,
                'threshold_pps': 100000,
                'window_seconds': 10,
                'auto_mitigate': True
            },
            'country_filter': {
                'enabled': True,
                'mode': 'blacklist',
                'blacklist': ['CN', 'RU', 'KP'],
                'whitelist': ['US', 'CA', 'GB', 'DE', 'FR'],
                'trigger_on_bandwidth': True,
                'trigger_threshold_mbps': 500
            },
            'blacklist': {
                'enabled': True,
                'file': '/etc/antiddos/blacklist.txt',
                'auto_save': True,
                'auto_blacklist': {
                    'enabled': True,
                    'connections_per_second': 100,
                    'duration_seconds': 3600
                }
            },
            'dos_filter': {
                'enabled': True,
                'syn_flood': {
                    'enabled': True,
                    'threshold': 50,
                    'action': 'drop'
                },
                'udp_flood': {
                    'enabled': True,
                    'threshold': 100,
                    'action': 'drop'
                },
                'icmp_flood': {
                    'enabled': True,
                    'threshold': 10,
                    'action': 'drop'
                },
                'connection_limit': {
                    'enabled': True,
                    'max_connections': 50,
                    'action': 'drop'
                }
            },
            'ssh_protection': {
                'enabled': True,
                'log_file': '/var/log/auth.log',
                'max_attempts': 5,
                'ban_time': 3600,
                'find_time': 600
            },
            'xcord': {
                'enabled': True,
                'port': 9999,
                'encryption_key': 'CHANGE_THIS_KEY',
                'peers': [],
                'sync_interval': 300,
                'auth_token': 'CHANGE_THIS_TOKEN'
            },
            'whitelist': {
                'enabled': True,
                'ips': ['127.0.0.1', '::1'],
                'file': '/etc/antiddos/whitelist.txt'
            },
            'services': {
                'enabled': False,
                'default_threshold_mbps': 500,
                'default_threshold_pps': 80000,
                'status_file': '/var/run/antiddos/service_stats.json',
                'window_seconds': 10,
                'recovery_cycles': 3,
                'auto_rate_limit': {
                    'enabled': True,
                    'limit_pps': 20000
                },
                'auto_udp_block': {
                    'enabled': False,
                    'min_pps': 2000,
                    'ban_connection_threshold': 1,
                    'ban_duration_seconds': 1800
                },
                'auto_blacklist': {
                    'enabled': True,
                    'min_connections': 200,
                    'duration_seconds': 1800
                },
                'auto_discovery': {
                    'enabled': False,
                    'mode': 'wings',  # wings or docker
                    'refresh_seconds': 60,
                    'wings': {
                        'api_url': 'http://127.0.0.1:8080',
                        'token': ''
                    },
                    'docker': {
                        'binary': 'docker'
                    }
                },
                'definitions': []
            },
            'advanced': {
                'use_conntrack': True,
                'max_conntrack_entries': 100000,
                'kernel_hardening': True,
                'allowed_ports': [3306, 5432, 6379, 22, 80, 443],
                'mysql': {
                    'port': 3306,
                    'allow_server_public_ip': True,
                    'server_public_ip': '',
                    'max_connections_per_ip': 10,
                    'rate_limit': '10/s',
                    'rate_limit_burst': 40,
                    'protection_enabled': True,
                    'trusted_ips': ['127.0.0.1']
                },
                'wings_api': {
                    'port': 8080,
                    'protection_enabled': True,
                    'trusted_ips': ['127.0.0.1'],
                    'rate_limit': '20/s',
                    'rate_limit_burst': 60
                },
                'strict_limits': {
                    'enabled': True,
                    'burst_multiplier': 3,
                    'syn_limit': 1500,
                    'udp_limit': 3000,
                    'icmp_limit': 400
                }
            }
        }
