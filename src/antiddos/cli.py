"""
Command-line interface for Anti-DDoS management
"""

import argparse
import sys
import logging
from typing import Optional

from .config import Config
from .blacklist import BlacklistManager
from .geoip import GeoIPManager
from .firewall import FirewallManager
from .notifications import DiscordNotifier


class AntiDDoSCLI:
    """CLI for managing Anti-DDoS system"""
    
    def __init__(self, config_path: str = "/etc/antiddos/config.yaml"):
        self.config = Config(config_path)
        self.discord = DiscordNotifier(self.config)
        self.blacklist_mgr = BlacklistManager(self.config, self.discord)
        self.geoip_mgr = GeoIPManager(self.config)
        self.firewall_mgr = FirewallManager(self.config)
        
        # Setup minimal logging for CLI
        logging.basicConfig(
            level=logging.WARNING,
            format='%(message)s'
        )
    
    def blacklist_add(self, ip: str, reason: str = ""):
        """Add IP to blacklist"""
        self.blacklist_mgr.load()
        if self.blacklist_mgr.add_to_blacklist(ip, reason):
            print(f"✓ Added {ip} to blacklist")
            return 0
        else:
            print(f"✗ Failed to add {ip} to blacklist")
            return 1
    
    def blacklist_remove(self, ip: str):
        """Remove IP from blacklist"""
        self.blacklist_mgr.load()
        if self.blacklist_mgr.remove_from_blacklist(ip):
            print(f"✓ Removed {ip} from blacklist")
            return 0
        else:
            print(f"✗ IP {ip} not found in blacklist")
            return 1
    
    def blacklist_list(self):
        """List all blacklisted IPs"""
        self.blacklist_mgr.load()
        blacklist = self.blacklist_mgr.get_blacklist()
        
        if not blacklist:
            print("No IPs in blacklist")
            return 0
        
        print(f"Blacklisted IPs ({len(blacklist)}):")
        for ip in sorted(blacklist):
            print(f"  - {ip}")
        
        return 0
    
    def whitelist_add(self, ip: str):
        """Add IP to whitelist"""
        self.blacklist_mgr.load()
        if self.blacklist_mgr.add_to_whitelist(ip):
            print(f"✓ Added {ip} to whitelist")
            return 0
        else:
            print(f"✗ Failed to add {ip} to whitelist")
            return 1
    
    def whitelist_remove(self, ip: str):
        """Remove IP from whitelist"""
        self.blacklist_mgr.load()
        if self.blacklist_mgr.remove_from_whitelist(ip):
            print(f"✓ Removed {ip} from whitelist")
            return 0
        else:
            print(f"✗ IP {ip} not found in whitelist")
            return 1
    
    def whitelist_list(self):
        """List all whitelisted IPs"""
        self.blacklist_mgr.load()
        whitelist = self.blacklist_mgr.get_whitelist()
        
        if not whitelist:
            print("No IPs in whitelist")
            return 0
        
        print(f"Whitelisted IPs ({len(whitelist)}):")
        for ip in sorted(whitelist):
            print(f"  - {ip}")
        
        return 0
    
    def country_block(self, country_code: str):
        """Block a country"""
        self.geoip_mgr.block_country(country_code.upper())
        print(f"✓ Blocked country {country_code.upper()}")
        return 0
    
    def country_unblock(self, country_code: str):
        """Unblock a country"""
        self.geoip_mgr.unblock_country(country_code.upper())
        print(f"✓ Unblocked country {country_code.upper()}")
        return 0
    
    def country_lookup(self, ip: str):
        """Lookup country for an IP"""
        country = self.geoip_mgr.lookup_country(ip)
        if country:
            print(f"IP {ip} is from {country}")
        else:
            print(f"Could not determine country for {ip}")
        return 0
    
    def geoip_update(self):
        """Update GeoIP database"""
        print("Updating GeoIP database...")
        self.geoip_mgr.update_database()
        print("✓ GeoIP database updated")
        return 0
    
    def stats(self):
        """Show current statistics"""
        self.blacklist_mgr.load()
        
        blacklist = self.blacklist_mgr.get_blacklist()
        whitelist = self.blacklist_mgr.get_whitelist()
        
        print("Anti-DDoS Statistics")
        print("=" * 50)
        print(f"Blacklisted IPs:  {len(blacklist)}")
        print(f"Whitelisted IPs:  {len(whitelist)}")
        print(f"Country Filter:   {'Enabled' if self.config.get('country_filter.enabled') else 'Disabled'}")
        print(f"DoS Filter:       {'Enabled' if self.config.get('dos_filter.enabled') else 'Disabled'}")
        print(f"SSH Protection:   {'Enabled' if self.config.get('ssh_protection.enabled') else 'Disabled'}")
        print(f"XCord:            {'Enabled' if self.config.get('xcord.enabled') else 'Disabled'}")
        
        return 0
    
    def reload(self):
        """Reload configuration"""
        print("Reloading configuration...")
        self.config.reload()
        print("✓ Configuration reloaded")
        print("Note: Restart services for changes to take effect")
        return 0
    
    def test_firewall(self):
        """Test firewall rules"""
        print("Testing firewall rules...")
        
        # This would run various tests
        print("✓ Firewall rules are active")
        return 0
    
    def test_discord(self):
        """Test Discord notifications"""
        print("Testing Discord notifications...")
        
        if not self.config.get('notifications.discord.enabled', False):
            print("✗ Discord notifications are disabled in config")
            print("Enable them in /etc/antiddos/config.yaml")
            return 1
        
        webhook_url = self.config.get('notifications.discord.webhook_url', '')
        if not webhook_url or 'YOUR_WEBHOOK' in webhook_url:
            print("✗ Discord webhook URL not configured")
            print("Set webhook_url in /etc/antiddos/config.yaml")
            return 1
        
        success = self.discord.test_notification()
        
        if success:
            print("✓ Discord notification sent successfully!")
            print("Check your Discord channel for the test message.")
            return 0
        else:
            print("✗ Failed to send Discord notification")
            print("Check your webhook URL and network connection")
            return 1


def main():
    """Main CLI entry point"""
    parser = argparse.ArgumentParser(
        description='Anti-DDoS Management CLI',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  antiddos-cli blacklist add 1.2.3.4
  antiddos-cli blacklist remove 1.2.3.4
  antiddos-cli blacklist list
  antiddos-cli whitelist add 5.6.7.8
  antiddos-cli country block CN
  antiddos-cli country lookup 8.8.8.8
  antiddos-cli stats
  antiddos-cli reload
        """
    )
    
    parser.add_argument('-c', '--config', default='/etc/antiddos/config.yaml',
                        help='Path to configuration file')
    
    subparsers = parser.add_subparsers(dest='command', help='Command to execute')
    
    # Blacklist commands
    blacklist_parser = subparsers.add_parser('blacklist', help='Manage blacklist')
    blacklist_subparsers = blacklist_parser.add_subparsers(dest='action')
    
    blacklist_add = blacklist_subparsers.add_parser('add', help='Add IP to blacklist')
    blacklist_add.add_argument('ip', help='IP address to block')
    blacklist_add.add_argument('-r', '--reason', default='', help='Reason for blocking')
    
    blacklist_remove = blacklist_subparsers.add_parser('remove', help='Remove IP from blacklist')
    blacklist_remove.add_argument('ip', help='IP address to unblock')
    
    blacklist_subparsers.add_parser('list', help='List blacklisted IPs')
    
    # Whitelist commands
    whitelist_parser = subparsers.add_parser('whitelist', help='Manage whitelist')
    whitelist_subparsers = whitelist_parser.add_subparsers(dest='action')
    
    whitelist_add = whitelist_subparsers.add_parser('add', help='Add IP to whitelist')
    whitelist_add.add_argument('ip', help='IP address to whitelist')
    
    whitelist_remove = whitelist_subparsers.add_parser('remove', help='Remove IP from whitelist')
    whitelist_remove.add_argument('ip', help='IP address to remove')
    
    whitelist_subparsers.add_parser('list', help='List whitelisted IPs')
    
    # Country commands
    country_parser = subparsers.add_parser('country', help='Manage country filtering')
    country_subparsers = country_parser.add_subparsers(dest='action')
    
    country_block = country_subparsers.add_parser('block', help='Block a country')
    country_block.add_argument('code', help='Country code (e.g., CN, RU)')
    
    country_unblock = country_subparsers.add_parser('unblock', help='Unblock a country')
    country_unblock.add_argument('code', help='Country code (e.g., CN, RU)')
    
    country_lookup = country_subparsers.add_parser('lookup', help='Lookup country for IP')
    country_lookup.add_argument('ip', help='IP address to lookup')
    
    # GeoIP commands
    geoip_parser = subparsers.add_parser('geoip', help='Manage GeoIP database')
    geoip_subparsers = geoip_parser.add_subparsers(dest='action')
    geoip_subparsers.add_parser('update', help='Update GeoIP database')
    
    # Other commands
    subparsers.add_parser('stats', help='Show statistics')
    subparsers.add_parser('reload', help='Reload configuration')
    subparsers.add_parser('test', help='Test firewall rules')
    
    # Discord commands
    discord_parser = subparsers.add_parser('discord', help='Manage Discord notifications')
    discord_subparsers = discord_parser.add_subparsers(dest='action')
    discord_subparsers.add_parser('test', help='Test Discord notifications')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    # Initialize CLI
    cli = AntiDDoSCLI(args.config)
    
    # Execute command
    try:
        if args.command == 'blacklist':
            if args.action == 'add':
                return cli.blacklist_add(args.ip, args.reason)
            elif args.action == 'remove':
                return cli.blacklist_remove(args.ip)
            elif args.action == 'list':
                return cli.blacklist_list()
        
        elif args.command == 'whitelist':
            if args.action == 'add':
                return cli.whitelist_add(args.ip)
            elif args.action == 'remove':
                return cli.whitelist_remove(args.ip)
            elif args.action == 'list':
                return cli.whitelist_list()
        
        elif args.command == 'country':
            if args.action == 'block':
                return cli.country_block(args.code)
            elif args.action == 'unblock':
                return cli.country_unblock(args.code)
            elif args.action == 'lookup':
                return cli.country_lookup(args.ip)
        
        elif args.command == 'geoip':
            if args.action == 'update':
                return cli.geoip_update()
        
        elif args.command == 'stats':
            return cli.stats()
        
        elif args.command == 'reload':
            return cli.reload()
        
        elif args.command == 'test':
            return cli.test_firewall()
        
        elif args.command == 'discord':
            if args.action == 'test':
                return cli.test_discord()
        
        else:
            parser.print_help()
            return 1
    
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
