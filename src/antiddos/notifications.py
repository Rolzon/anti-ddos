"""
Discord notifications for Anti-DDoS system
Sends alerts about attacks, mitigations, and blocked IPs
"""

import requests
import logging
import json
from datetime import datetime
from typing import Dict, List, Optional
from enum import Enum


class AlertLevel(Enum):
    """Alert severity levels"""
    INFO = "info"
    WARNING = "warning"
    CRITICAL = "critical"
    SUCCESS = "success"


class DiscordNotifier:
    """Send notifications to Discord via webhooks"""
    
    def __init__(self, config):
        self.config = config
        self.logger = logging.getLogger(__name__)
        
        self.webhook_url = self.config.get('notifications.discord.webhook_url', '')
        self.enabled = self.config.get('notifications.discord.enabled', False)
        self.public_channel = self.config.get('notifications.discord.public_channel', '')
        self.admin_channel = self.config.get('notifications.discord.admin_channel', '')
        self.mention_role = self.config.get('notifications.discord.mention_role', '')
        
        # Notification settings
        self.notify_attacks = self.config.get('notifications.discord.notify_attacks', True)
        self.notify_mitigations = self.config.get('notifications.discord.notify_mitigations', True)
        self.notify_blocks = self.config.get('notifications.discord.notify_blocks', True)
        self.notify_unblocks = self.config.get('notifications.discord.notify_unblocks', False)
        
        # Thresholds for public notifications
        self.public_threshold_mbps = self.config.get('notifications.discord.public_threshold_mbps', 500)
        self.public_threshold_ips = self.config.get('notifications.discord.public_threshold_ips', 10)
    
    def _get_color(self, level: AlertLevel) -> int:
        """Get Discord embed color based on alert level"""
        colors = {
            AlertLevel.INFO: 0x3498db,      # Blue
            AlertLevel.WARNING: 0xf39c12,   # Orange
            AlertLevel.CRITICAL: 0xe74c3c,  # Red
            AlertLevel.SUCCESS: 0x2ecc71    # Green
        }
        return colors.get(level, 0x95a5a6)
    
    def _send_webhook(self, webhook_url: str, embed: Dict, content: str = "") -> bool:
        """Send message to Discord webhook"""
        if not self.enabled or not webhook_url:
            return False
        
        try:
            payload = {
                "content": content,
                "embeds": [embed]
            }
            
            response = requests.post(
                webhook_url,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=10
            )
            
            if response.status_code == 204:
                self.logger.debug("Discord notification sent successfully")
                return True
            else:
                self.logger.error(f"Discord webhook failed: {response.status_code} - {response.text}")
                return False
        
        except Exception as e:
            self.logger.error(f"Error sending Discord notification: {e}")
            return False
    
    def notify_attack_detected(self, mbps: float, pps: int, source_ips: List[str] = None):
        """Notify about detected DDoS attack"""
        if not self.notify_attacks:
            return
        
        is_major_attack = mbps >= self.public_threshold_mbps
        
        # Determine severity
        if mbps >= 1000:
            level = AlertLevel.CRITICAL
            severity = "🚨 CRÍTICO"
        elif mbps >= 500:
            level = AlertLevel.WARNING
            severity = "⚠️ ALTO"
        else:
            level = AlertLevel.INFO
            severity = "ℹ️ MODERADO"
        
        embed = {
            "title": f"{severity} - Ataque DDoS Detectado",
            "description": "Se ha detectado un ataque DDoS en el servidor.",
            "color": self._get_color(level),
            "fields": [
                {
                    "name": "📊 Tráfico",
                    "value": f"**{mbps:.2f} Mbps**\n{pps:,} PPS",
                    "inline": True
                },
                {
                    "name": "🕐 Hora",
                    "value": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    "inline": True
                },
                {
                    "name": "🛡️ Estado",
                    "value": "Mitigación activada automáticamente",
                    "inline": False
                }
            ],
            "footer": {
                "text": "Sistema Anti-DDoS"
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Add source IPs if available
        if source_ips:
            top_ips = source_ips[:5]  # Show top 5
            embed["fields"].append({
                "name": "🎯 IPs Principales",
                "value": "\n".join([f"`{ip}`" for ip in top_ips]),
                "inline": False
            })
        
        # Mention role for critical attacks
        content = ""
        if is_major_attack and self.mention_role:
            content = f"<@&{self.mention_role}>"
        
        # Send to appropriate channels
        if is_major_attack and self.public_channel:
            # Major attack - notify public
            self._send_webhook(self.public_channel, embed, content)
        
        if self.admin_channel:
            # Always notify admins
            self._send_webhook(self.admin_channel, embed, content)
        elif self.webhook_url:
            # Fallback to main webhook
            self._send_webhook(self.webhook_url, embed, content)
    
    def notify_mitigation_activated(self, reason: str, actions: List[str]):
        """Notify about mitigation activation"""
        if not self.notify_mitigations:
            return
        
        embed = {
            "title": "🛡️ Mitigación DDoS Activada",
            "description": f"**Razón:** {reason}",
            "color": self._get_color(AlertLevel.WARNING),
            "fields": [
                {
                    "name": "⚙️ Acciones Tomadas",
                    "value": "\n".join([f"• {action}" for action in actions]),
                    "inline": False
                },
                {
                    "name": "🕐 Hora",
                    "value": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    "inline": True
                }
            ],
            "footer": {
                "text": "Sistema Anti-DDoS"
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        if self.admin_channel:
            self._send_webhook(self.admin_channel, embed)
        elif self.webhook_url:
            self._send_webhook(self.webhook_url, embed)

    def notify_port_blocked(self, service_name: str, port: int, protocol: str, total_pps: int):
        """Notify when a service's port gets fully blocked (e.g., UDP flood)"""
        if not self.notify_blocks:
            return

        embed = {
            "title": "⛔ Puerto bloqueado",
            "description": (
                f"Se bloqueó **{service_name}** porque {protocol.upper()} {port} superó el umbral configurado."
            ),
            "color": self._get_color(AlertLevel.DANGER),
            "fields": [
                {
                    "name": "🔌 Puerto",
                    "value": f"{port}/{protocol.lower()}",
                    "inline": True
                },
                {
                    "name": "📈 PPS detectados",
                    "value": f"{total_pps:,}",
                    "inline": True
                },
                {
                    "name": "🕐 Hora",
                    "value": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    "inline": False
                }
            ],
            "footer": {"text": "Sistema Anti-DDoS"},
            "timestamp": datetime.utcnow().isoformat()
        }

        if self.admin_channel:
            self._send_webhook(self.admin_channel, embed)
        elif self.webhook_url:
            self._send_webhook(self.webhook_url, embed)

    def notify_service_attack(self, service_name: str, stats, actions: List[str]):
        """Notify when a specific service exceeds thresholds"""
        if not self.notify_attacks:
            return

        action_text = ", ".join(actions) if actions else "Monitorización reforzada"

        embed = {
            "title": f"🎮 Servicio bajo ataque: {service_name}",
            "description": "Se detectó tráfico elevado en un servicio específico.",
            "color": self._get_color(AlertLevel.WARNING),
            "fields": [
                {
                    "name": "📊 Tráfico",
                    "value": f"{stats.total_mbps:.2f} Mbps / {stats.total_pps:,} PPS",
                    "inline": True
                },
                {
                    "name": "⚙️ Acción",
                    "value": action_text,
                    "inline": False
                },
                {
                    "name": "🔗 Conexiones",
                    "value": str(stats.connections),
                    "inline": True
                },
            ],
            "footer": {"text": "Sistema Anti-DDoS"},
            "timestamp": datetime.utcnow().isoformat()
        }

        if getattr(stats, 'top_attackers', None):
            attackers = stats.top_attackers[:5]
            embed["fields"].append({
                "name": "🎯 IPs principales",
                "value": "\n".join([f"`{ip}` ({count})" for ip, count in attackers]) or "N/A",
                "inline": False
            })

        if self.admin_channel:
            self._send_webhook(self.admin_channel, embed)
        elif self.webhook_url:
            self._send_webhook(self.webhook_url, embed)

    def notify_service_recovered(self, service_name: str):
        """Notify when a service returns to normal traffic"""
        if not self.notify_mitigations:
            return

        embed = {
            "title": f"✅ Servicio normalizado: {service_name}",
            "description": "El tráfico volvió a niveles normales.",
            "color": self._get_color(AlertLevel.SUCCESS),
            "fields": [
                {
                    "name": "🕐 Hora",
                    "value": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    "inline": True
                }
            ],
            "footer": {"text": "Sistema Anti-DDoS"},
            "timestamp": datetime.utcnow().isoformat()
        }

        if self.admin_channel:
            self._send_webhook(self.admin_channel, embed)
        elif self.webhook_url:
            self._send_webhook(self.webhook_url, embed)
    
    def notify_mitigation_deactivated(self):
        """Notify about mitigation deactivation"""
        if not self.notify_mitigations:
            return
        
        embed = {
            "title": "✅ Mitigación DDoS Desactivada",
            "description": "El tráfico ha vuelto a la normalidad.",
            "color": self._get_color(AlertLevel.SUCCESS),
            "fields": [
                {
                    "name": "🕐 Hora",
                    "value": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    "inline": True
                }
            ],
            "footer": {
                "text": "Sistema Anti-DDoS"
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        if self.admin_channel:
            self._send_webhook(self.admin_channel, embed)
        elif self.webhook_url:
            self._send_webhook(self.webhook_url, embed)
    
    def notify_ip_blocked(self, ip: str, reason: str, duration: Optional[int] = None):
        """Notify about IP being blocked"""
        if not self.notify_blocks:
            return
        
        duration_text = f"{duration // 3600} horas" if duration else "Permanente"
        
        embed = {
            "title": "🚫 IP Bloqueada Automáticamente",
            "description": f"Se ha bloqueado una IP maliciosa.",
            "color": self._get_color(AlertLevel.WARNING),
            "fields": [
                {
                    "name": "🎯 IP",
                    "value": f"`{ip}`",
                    "inline": True
                },
                {
                    "name": "⏱️ Duración",
                    "value": duration_text,
                    "inline": True
                },
                {
                    "name": "📝 Razón",
                    "value": reason,
                    "inline": False
                },
                {
                    "name": "🕐 Hora",
                    "value": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    "inline": True
                }
            ],
            "footer": {
                "text": "Sistema Anti-DDoS"
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Only send to admin channel for individual blocks
        if self.admin_channel:
            self._send_webhook(self.admin_channel, embed)
        elif self.webhook_url:
            self._send_webhook(self.webhook_url, embed)
    
    def notify_bulk_blocks(self, ips: List[str], reason: str):
        """Notify about multiple IPs being blocked"""
        if not self.notify_blocks or len(ips) < self.public_threshold_ips:
            return
        
        # This is a major event - notify public
        embed = {
            "title": "🚫 Bloqueo Masivo de IPs",
            "description": f"Se han bloqueado **{len(ips)} IPs** automáticamente.",
            "color": self._get_color(AlertLevel.CRITICAL),
            "fields": [
                {
                    "name": "📝 Razón",
                    "value": reason,
                    "inline": False
                },
                {
                    "name": "🎯 Ejemplos de IPs Bloqueadas",
                    "value": "\n".join([f"`{ip}`" for ip in ips[:10]]),
                    "inline": False
                },
                {
                    "name": "🕐 Hora",
                    "value": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    "inline": True
                }
            ],
            "footer": {
                "text": "Sistema Anti-DDoS"
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        if len(ips) > 10:
            embed["fields"].append({
                "name": "ℹ️ Nota",
                "value": f"Y {len(ips) - 10} IPs más...",
                "inline": False
            })
        
        # Notify public for bulk blocks
        if self.public_channel:
            self._send_webhook(self.public_channel, embed)
        
        if self.admin_channel:
            self._send_webhook(self.admin_channel, embed)
        elif self.webhook_url:
            self._send_webhook(self.webhook_url, embed)
    
    def notify_ip_unblocked(self, ip: str, reason: str = ""):
        """Notify about IP being unblocked"""
        if not self.notify_unblocks:
            return
        
        embed = {
            "title": "✅ IP Desbloqueada",
            "description": f"La IP `{ip}` ha sido desbloqueada.",
            "color": self._get_color(AlertLevel.SUCCESS),
            "fields": [
                {
                    "name": "🎯 IP",
                    "value": f"`{ip}`",
                    "inline": True
                },
                {
                    "name": "🕐 Hora",
                    "value": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    "inline": True
                }
            ],
            "footer": {
                "text": "Sistema Anti-DDoS"
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        if reason:
            embed["fields"].insert(1, {
                "name": "📝 Razón",
                "value": reason,
                "inline": False
            })
        
        if self.admin_channel:
            self._send_webhook(self.admin_channel, embed)
        elif self.webhook_url:
            self._send_webhook(self.webhook_url, embed)
    
    def notify_ssh_attack(self, ip: str, attempts: int):
        """Notify about SSH attack"""
        embed = {
            "title": "🔐 Ataque SSH Detectado",
            "description": f"Se ha detectado un ataque de fuerza bruta SSH.",
            "color": self._get_color(AlertLevel.WARNING),
            "fields": [
                {
                    "name": "🎯 IP Atacante",
                    "value": f"`{ip}`",
                    "inline": True
                },
                {
                    "name": "🔢 Intentos",
                    "value": str(attempts),
                    "inline": True
                },
                {
                    "name": "🛡️ Acción",
                    "value": "IP bloqueada automáticamente",
                    "inline": False
                },
                {
                    "name": "🕐 Hora",
                    "value": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    "inline": True
                }
            ],
            "footer": {
                "text": "Sistema Anti-DDoS - SSH Protection"
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        if self.admin_channel:
            self._send_webhook(self.admin_channel, embed)
        elif self.webhook_url:
            self._send_webhook(self.webhook_url, embed)
    
    def notify_country_blocked(self, country_code: str, ip_count: int):
        """Notify about country being blocked"""
        embed = {
            "title": "🌍 País Bloqueado",
            "description": f"Se ha bloqueado el país **{country_code}**.",
            "color": self._get_color(AlertLevel.INFO),
            "fields": [
                {
                    "name": "🏳️ País",
                    "value": country_code,
                    "inline": True
                },
                {
                    "name": "🔢 Rangos de IP",
                    "value": str(ip_count),
                    "inline": True
                },
                {
                    "name": "🕐 Hora",
                    "value": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    "inline": True
                }
            ],
            "footer": {
                "text": "Sistema Anti-DDoS - GeoIP Filter"
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        if self.admin_channel:
            self._send_webhook(self.admin_channel, embed)
        elif self.webhook_url:
            self._send_webhook(self.webhook_url, embed)
    
    def send_statistics_report(self, stats: Dict):
        """Send periodic statistics report"""
        embed = {
            "title": "📊 Reporte de Estadísticas Anti-DDoS",
            "description": "Resumen de actividad del sistema",
            "color": self._get_color(AlertLevel.INFO),
            "fields": [
                {
                    "name": "🚫 IPs Bloqueadas",
                    "value": str(stats.get('blocked_ips', 0)),
                    "inline": True
                },
                {
                    "name": "✅ IPs en Lista Blanca",
                    "value": str(stats.get('whitelisted_ips', 0)),
                    "inline": True
                },
                {
                    "name": "🌍 Países Bloqueados",
                    "value": str(stats.get('blocked_countries', 0)),
                    "inline": True
                },
                {
                    "name": "🔐 Ataques SSH Bloqueados",
                    "value": str(stats.get('ssh_attacks', 0)),
                    "inline": True
                },
                {
                    "name": "🛡️ Mitigaciones Activadas",
                    "value": str(stats.get('mitigations', 0)),
                    "inline": True
                },
                {
                    "name": "📈 Tráfico Promedio",
                    "value": f"{stats.get('avg_traffic_mbps', 0):.2f} Mbps",
                    "inline": True
                }
            ],
            "footer": {
                "text": "Sistema Anti-DDoS - Reporte Automático"
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        if self.admin_channel:
            self._send_webhook(self.admin_channel, embed)
        elif self.webhook_url:
            self._send_webhook(self.webhook_url, embed)
    
    def test_notification(self):
        """Send test notification"""
        embed = {
            "title": "✅ Prueba de Notificación",
            "description": "El sistema de notificaciones Discord está funcionando correctamente.",
            "color": self._get_color(AlertLevel.SUCCESS),
            "fields": [
                {
                    "name": "🕐 Hora",
                    "value": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    "inline": True
                }
            ],
            "footer": {
                "text": "Sistema Anti-DDoS"
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        success = False
        if self.webhook_url:
            success = self._send_webhook(self.webhook_url, embed)
        
        if self.admin_channel:
            success = self._send_webhook(self.admin_channel, embed) or success
        
        if self.public_channel:
            success = self._send_webhook(self.public_channel, embed) or success
        
        return success
