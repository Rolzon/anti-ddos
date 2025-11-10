"""
XCord Blacklist Handler - Encrypted blacklist synchronization across servers
"""

import socket
import json
import logging
import threading
import time
import signal
import sys
from typing import List, Dict, Set
from datetime import datetime
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2
import base64


class XCordHandler:
    """Handle encrypted blacklist synchronization"""
    
    def __init__(self, config):
        self.config = config
        self.logger = logging.getLogger(__name__)
        
        self.port = self.config.get('xcord.port', 9999)
        self.peers = self.config.get('xcord.peers', [])
        self.sync_interval = self.config.get('xcord.sync_interval', 300)
        self.auth_token = self.config.get('xcord.auth_token', '')
        
        # Initialize encryption
        self.cipher = self._init_encryption()
        
        self.running = False
        self.server_socket = None
        self.local_blacklist: Set[str] = set()
        
        # Setup signal handlers
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
    
    def _init_encryption(self) -> Fernet:
        """Initialize Fernet encryption with configured key"""
        encryption_key = self.config.get('xcord.encryption_key', '')
        
        if not encryption_key or encryption_key == 'CHANGE_THIS_TO_A_SECURE_KEY_32_CHARS_MINIMUM':
            self.logger.warning("Using default encryption key - CHANGE THIS IN PRODUCTION!")
            encryption_key = 'default_insecure_key_change_this_immediately'
        
        # Derive a proper Fernet key from the configured key
        kdf = PBKDF2(
            algorithm=hashes.SHA256(),
            length=32,
            salt=b'antiddos_xcord_salt',  # In production, use a random salt
            iterations=100000,
        )
        key = base64.urlsafe_b64encode(kdf.derive(encryption_key.encode()))
        
        return Fernet(key)
    
    def signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.stop()
    
    def start(self):
        """Start XCord handler"""
        if not self.config.get('xcord.enabled', True):
            self.logger.info("XCord is disabled")
            return
        
        self.logger.info(f"Starting XCord handler on port {self.port}")
        self.running = True
        
        # Start server thread
        server_thread = threading.Thread(target=self._run_server, daemon=True)
        server_thread.start()
        
        # Start sync thread
        sync_thread = threading.Thread(target=self._sync_loop, daemon=True)
        sync_thread.start()
        
        # Keep main thread alive
        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            self.stop()
    
    def _run_server(self):
        """Run the XCord server to receive blacklist updates"""
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.server_socket.bind(('0.0.0.0', self.port))
            self.server_socket.listen(5)
            self.server_socket.settimeout(1.0)
            
            self.logger.info(f"XCord server listening on port {self.port}")
            
            while self.running:
                try:
                    client_socket, address = self.server_socket.accept()
                    self.logger.info(f"Connection from {address}")
                    
                    # Handle in separate thread
                    client_thread = threading.Thread(
                        target=self._handle_client,
                        args=(client_socket, address),
                        daemon=True
                    )
                    client_thread.start()
                
                except socket.timeout:
                    continue
                except Exception as e:
                    if self.running:
                        self.logger.error(f"Error accepting connection: {e}")
        
        except Exception as e:
            self.logger.error(f"Error starting server: {e}")
        finally:
            if self.server_socket:
                self.server_socket.close()
    
    def _handle_client(self, client_socket: socket.socket, address: tuple):
        """Handle incoming client connection"""
        try:
            # Receive data
            data = b''
            while True:
                chunk = client_socket.recv(4096)
                if not chunk:
                    break
                data += chunk
                if len(data) > 1024 * 1024:  # 1MB limit
                    self.logger.warning(f"Data too large from {address}")
                    return
            
            if not data:
                return
            
            # Decrypt and parse
            try:
                decrypted = self.cipher.decrypt(data)
                message = json.loads(decrypted.decode('utf-8'))
            except Exception as e:
                self.logger.error(f"Failed to decrypt message from {address}: {e}")
                return
            
            # Verify authentication
            if message.get('auth_token') != self.auth_token:
                self.logger.warning(f"Invalid auth token from {address}")
                return
            
            # Process message
            if message.get('type') == 'blacklist_update':
                self._process_blacklist_update(message.get('blacklist', []), address)
            elif message.get('type') == 'blacklist_request':
                self._send_blacklist(client_socket)
        
        except Exception as e:
            self.logger.error(f"Error handling client {address}: {e}")
        finally:
            client_socket.close()
    
    def _process_blacklist_update(self, blacklist: List[str], source: tuple):
        """Process received blacklist update"""
        self.logger.info(f"Received blacklist update from {source} with {len(blacklist)} IPs")
        
        from .blacklist import BlacklistManager
        blacklist_mgr = BlacklistManager(self.config)
        
        # Add new IPs to local blacklist
        added = 0
        for ip in blacklist:
            if ip not in self.local_blacklist:
                if blacklist_mgr.add_to_blacklist(ip, reason=f"XCord sync from {source[0]}"):
                    self.local_blacklist.add(ip)
                    added += 1
        
        if added > 0:
            self.logger.info(f"Added {added} new IPs from XCord sync")
    
    def _send_blacklist(self, client_socket: socket.socket):
        """Send local blacklist to requesting peer"""
        try:
            from .blacklist import BlacklistManager
            blacklist_mgr = BlacklistManager(self.config)
            
            blacklist = list(blacklist_mgr.get_blacklist())
            
            message = {
                'type': 'blacklist_update',
                'auth_token': self.auth_token,
                'blacklist': blacklist,
                'timestamp': datetime.now().isoformat()
            }
            
            # Encrypt and send
            encrypted = self.cipher.encrypt(json.dumps(message).encode('utf-8'))
            client_socket.sendall(encrypted)
            
            self.logger.info(f"Sent blacklist with {len(blacklist)} IPs")
        
        except Exception as e:
            self.logger.error(f"Error sending blacklist: {e}")
    
    def _sync_loop(self):
        """Periodically sync with peers"""
        while self.running:
            try:
                time.sleep(self.sync_interval)
                
                if not self.peers:
                    continue
                
                self.logger.info("Starting blacklist sync with peers")
                
                for peer in self.peers:
                    try:
                        self._sync_with_peer(peer)
                    except Exception as e:
                        self.logger.error(f"Error syncing with peer {peer}: {e}")
            
            except Exception as e:
                self.logger.error(f"Error in sync loop: {e}")
    
    def _sync_with_peer(self, peer: str):
        """Sync blacklist with a specific peer"""
        try:
            # Parse peer address
            if ':' in peer:
                host, port = peer.rsplit(':', 1)
                port = int(port)
            else:
                host = peer
                port = self.port
            
            self.logger.debug(f"Syncing with peer {host}:{port}")
            
            # Connect to peer
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(10.0)
            sock.connect((host, port))
            
            # Request blacklist
            message = {
                'type': 'blacklist_request',
                'auth_token': self.auth_token,
                'timestamp': datetime.now().isoformat()
            }
            
            # Encrypt and send
            encrypted = self.cipher.encrypt(json.dumps(message).encode('utf-8'))
            sock.sendall(encrypted)
            
            # Receive response
            data = b''
            while True:
                chunk = sock.recv(4096)
                if not chunk:
                    break
                data += chunk
                if len(data) > 1024 * 1024:  # 1MB limit
                    break
            
            sock.close()
            
            if not data:
                return
            
            # Decrypt and parse
            decrypted = self.cipher.decrypt(data)
            response = json.loads(decrypted.decode('utf-8'))
            
            # Process blacklist
            if response.get('type') == 'blacklist_update':
                self._process_blacklist_update(
                    response.get('blacklist', []),
                    (host, port)
                )
        
        except Exception as e:
            self.logger.error(f"Error syncing with {peer}: {e}")
    
    def broadcast_blacklist_update(self, ip: str):
        """Broadcast a new blacklist entry to all peers"""
        if not self.peers:
            return
        
        self.logger.info(f"Broadcasting blacklist update for {ip}")
        
        message = {
            'type': 'blacklist_update',
            'auth_token': self.auth_token,
            'blacklist': [ip],
            'timestamp': datetime.now().isoformat()
        }
        
        encrypted = self.cipher.encrypt(json.dumps(message).encode('utf-8'))
        
        for peer in self.peers:
            try:
                if ':' in peer:
                    host, port = peer.rsplit(':', 1)
                    port = int(port)
                else:
                    host = peer
                    port = self.port
                
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(5.0)
                sock.connect((host, port))
                sock.sendall(encrypted)
                sock.close()
                
                self.logger.debug(f"Sent update to {peer}")
            
            except Exception as e:
                self.logger.error(f"Failed to send update to {peer}: {e}")
    
    def stop(self):
        """Stop XCord handler"""
        self.running = False
        
        if self.server_socket:
            self.server_socket.close()
        
        self.logger.info("XCord handler stopped")
        sys.exit(0)


def main():
    """Main entry point"""
    import argparse
    from .config import Config
    
    parser = argparse.ArgumentParser(description='XCord Blacklist Handler')
    parser.add_argument('-c', '--config', default='/etc/antiddos/config.yaml',
                        help='Path to configuration file')
    args = parser.parse_args()
    
    # Setup logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('/var/log/antiddos/xcord.log'),
            logging.StreamHandler(sys.stdout)
        ]
    )
    
    config = Config(args.config)
    xcord = XCordHandler(config)
    xcord.start()


if __name__ == '__main__':
    main()
