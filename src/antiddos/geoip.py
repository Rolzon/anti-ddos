"""
GeoIP-based country filtering
"""

import logging
import geoip2.database
import requests
import os
from typing import List, Optional
from pathlib import Path


class GeoIPManager:
    """Manage GeoIP-based country filtering"""
    
    def __init__(self, config):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.db_path = "/usr/share/GeoIP/GeoLite2-Country.mmdb"
        self.reader = None
        self.active_countries = set()
        
        self.initialize_database()
    
    def initialize_database(self):
        """Initialize GeoIP database"""
        if os.path.exists(self.db_path):
            try:
                self.reader = geoip2.database.Reader(self.db_path)
                self.logger.info("GeoIP database loaded successfully")
            except Exception as e:
                self.logger.error(f"Failed to load GeoIP database: {e}")
        else:
            self.logger.warning(f"GeoIP database not found at {self.db_path}")
            self.logger.info("Run 'sudo antiddos-cli geoip update' to download the database")
    
    def lookup_country(self, ip: str) -> Optional[str]:
        """Lookup country code for an IP address"""
        if not self.reader:
            return None
        
        try:
            response = self.reader.country(ip)
            return response.country.iso_code
        except Exception as e:
            self.logger.debug(f"Failed to lookup country for {ip}: {e}")
            return None
    
    def get_country_ip_ranges(self, country_code: str) -> List[str]:
        """
        Get IP ranges for a country
        This is a simplified version - in production, you'd use a proper IP range database
        """
        # This would typically query a database of IP ranges by country
        # For now, return empty list as placeholder
        self.logger.warning("Country IP range lookup not fully implemented")
        return []
    
    def apply_country_filter(self):
        """Apply country-based filtering"""
        if not self.config.get('country_filter.enabled', True):
            return
        
        mode = self.config.get('country_filter.mode', 'blacklist')
        
        if mode == 'blacklist':
            countries = self.config.get('country_filter.blacklist', [])
            self.logger.info(f"Applying country blacklist: {', '.join(countries)}")
            
            for country in countries:
                self.block_country(country)
        
        elif mode == 'whitelist':
            countries = self.config.get('country_filter.whitelist', [])
            self.logger.info(f"Applying country whitelist: {', '.join(countries)}")
            
            # In whitelist mode, we'd need to block all countries except whitelisted ones
            # This is more complex and would require a complete country list
            self.logger.warning("Whitelist mode requires blocking all non-whitelisted countries")
    
    def remove_country_filter(self):
        """Remove all country-based filters"""
        self.logger.info("Removing country filters")
        
        from .firewall import FirewallManager
        firewall = FirewallManager(self.config)
        
        for country in self.active_countries:
            firewall.unblock_country(country)
        
        self.active_countries.clear()
    
    def block_country(self, country_code: str):
        """Block a specific country"""
        if country_code in self.active_countries:
            self.logger.info(f"Country {country_code} already blocked")
            return
        
        self.logger.info(f"Blocking country: {country_code}")
        
        # Get IP ranges for country
        ip_ranges = self.get_country_ip_ranges(country_code)
        
        if not ip_ranges:
            self.logger.warning(f"No IP ranges found for country {country_code}")
            return
        
        # Apply firewall rules
        from .firewall import FirewallManager
        firewall = FirewallManager(self.config)
        firewall.block_country(country_code, ip_ranges)
        
        self.active_countries.add(country_code)
    
    def unblock_country(self, country_code: str):
        """Unblock a specific country"""
        if country_code not in self.active_countries:
            self.logger.info(f"Country {country_code} not currently blocked")
            return
        
        self.logger.info(f"Unblocking country: {country_code}")
        
        from .firewall import FirewallManager
        firewall = FirewallManager(self.config)
        firewall.unblock_country(country_code)
        
        self.active_countries.discard(country_code)
    
    def download_database(self):
        """
        Download GeoIP database
        Note: MaxMind requires a license key for downloads
        """
        self.logger.info("Downloading GeoIP database...")
        
        # This is a placeholder - actual implementation would require MaxMind license key
        self.logger.warning(
            "GeoIP database download requires MaxMind license key. "
            "Please register at https://www.maxmind.com/en/geolite2/signup "
            "and configure your license key."
        )
        
        # Example download URL (requires license key):
        # https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=YOUR_LICENSE_KEY&suffix=tar.gz
    
    def update_database(self):
        """Update GeoIP database"""
        self.logger.info("Updating GeoIP database...")
        self.download_database()
        
        # Reload database
        if self.reader:
            self.reader.close()
        self.initialize_database()
