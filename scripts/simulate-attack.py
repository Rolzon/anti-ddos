#!/usr/bin/env python3
"""
Script para simular un ataque DDoS y probar notificaciones de Discord
SOLO PARA PRUEBAS - No usar en producción
"""

import sys
import time
import subprocess
import socket
import threading
from pathlib import Path

# Agregar el path del módulo
sys.path.insert(0, '/opt/anti-ddos/src')

try:
    from antiddos.notifications import DiscordNotifier
    from antiddos.config import Config
except ImportError:
    print("Error: No se pudo importar el módulo antiddos")
    print("Asegúrate de que el sistema esté instalado correctamente")
    sys.exit(1)


class AttackSimulator:
    """Simulador de ataques DDoS para pruebas"""
    
    def __init__(self):
        self.config = Config('/etc/antiddos/config.yaml')
        self.discord = DiscordNotifier(self.config)
    
    def test_discord_connection(self):
        """Probar conexión con Discord"""
        print("\n=== Probando Conexión con Discord ===\n")
        
        if not self.config.get('notifications.discord.enabled', False):
            print("❌ Discord está deshabilitado en la configuración")
            print("\nPara habilitar:")
            print("1. Editar: sudo nano /etc/antiddos/config.yaml")
            print("2. Cambiar 'enabled: false' a 'enabled: true' en la sección discord")
            print("3. Agregar tu webhook_url")
            return False
        
        webhook = self.config.get('notifications.discord.webhook_url', '')
        if not webhook or webhook == 'YOUR_WEBHOOK_URL_HERE':
            print("❌ Webhook de Discord no configurado")
            print("\nPara configurar:")
            print("1. Crear un webhook en tu servidor de Discord")
            print("2. Editar: sudo nano /etc/antiddos/config.yaml")
            print("3. Pegar el webhook_url")
            return False
        
        print(f"✓ Discord habilitado")
        print(f"✓ Webhook configurado: {webhook[:50]}...")
        
        # Enviar mensaje de prueba
        print("\nEnviando mensaje de prueba...")
        success = self.discord.send_test_message()
        
        if success:
            print("✓ Mensaje de prueba enviado exitosamente")
            print("\n🎉 Revisa tu canal de Discord!")
            return True
        else:
            print("❌ Error al enviar mensaje")
            return False
    
    def simulate_ddos_attack(self):
        """Simular un ataque DDoS"""
        print("\n=== Simulando Ataque DDoS ===\n")
        
        # Datos simulados del ataque
        attack_data = {
            'bandwidth_mbps': 1500,  # 1.5 Gbps
            'packets_per_second': 250000,  # 250k PPS
            'source_ips': ['1.2.3.4', '5.6.7.8', '9.10.11.12'],
            'duration': 120  # 2 minutos
        }
        
        print(f"Simulando ataque con:")
        print(f"  - Ancho de banda: {attack_data['bandwidth_mbps']} Mbps")
        print(f"  - Paquetes/seg: {attack_data['packets_per_second']:,}")
        print(f"  - IPs atacantes: {len(attack_data['source_ips'])}")
        print(f"  - Duración: {attack_data['duration']} segundos")
        print()
        
        # Enviar notificación de ataque detectado
        print("Enviando notificación de ataque detectado...")
        self.discord.notify_attack_detected(
            bandwidth_mbps=attack_data['bandwidth_mbps'],
            packets_per_second=attack_data['packets_per_second'],
            threshold_mbps=1000
        )
        
        time.sleep(2)
        
        # Enviar notificación de mitigación activada
        print("Enviando notificación de mitigación activada...")
        self.discord.notify_mitigation_activated(
            bandwidth_mbps=attack_data['bandwidth_mbps'],
            packets_per_second=attack_data['packets_per_second'],
            actions=['country_filtering', 'strict_rate_limits']
        )
        
        time.sleep(2)
        
        # Simular bloqueo de IPs
        print("Simulando bloqueo de IPs atacantes...")
        for ip in attack_data['source_ips']:
            self.discord.notify_ip_blocked(ip, f"Ataque DDoS simulado - {attack_data['packets_per_second']:,} PPS")
            print(f"  ✓ IP bloqueada: {ip}")
            time.sleep(1)
        
        print("\n✓ Simulación de ataque completada")
        print("🎉 Revisa tu canal de Discord para ver las notificaciones!")
    
    def simulate_ssh_attack(self):
        """Simular un ataque SSH"""
        print("\n=== Simulando Ataque SSH ===\n")
        
        attacker_ip = "8.8.8.8"
        failed_attempts = 10
        
        print(f"Simulando {failed_attempts} intentos fallidos desde {attacker_ip}")
        print()
        
        # Enviar notificación de ataque SSH
        self.discord.notify_ssh_attack(attacker_ip, failed_attempts)
        
        print("✓ Notificación de ataque SSH enviada")
        print("🎉 Revisa tu canal de Discord!")
    
    def simulate_ip_block(self):
        """Simular bloqueo de IP"""
        print("\n=== Simulando Bloqueo de IP ===\n")
        
        test_ip = "1.2.3.4"
        reason = "Prueba de notificación Discord - Tráfico sospechoso detectado"
        
        print(f"Bloqueando IP: {test_ip}")
        print(f"Razón: {reason}")
        print()
        
        # Enviar notificación
        self.discord.notify_ip_blocked(test_ip, reason)
        
        print("✓ Notificación de bloqueo enviada")
        print("🎉 Revisa tu canal de Discord!")
        
        # Agregar a blacklist real (opcional)
        print("\n¿Agregar a blacklist real? (s/n): ", end='')
        response = input().strip().lower()
        
        if response == 's':
            try:
                subprocess.run(['antiddos-cli', 'blacklist', 'add', test_ip, reason], check=True)
                print(f"✓ IP {test_ip} agregada a blacklist")
                print(f"\nPara remover: sudo antiddos-cli blacklist remove {test_ip}")
            except Exception as e:
                print(f"Error al agregar a blacklist: {e}")


def main():
    """Función principal"""
    print("╔════════════════════════════════════════════════════╗")
    print("║   Simulador de Ataques DDoS - Prueba Discord      ║")
    print("║              SOLO PARA PRUEBAS                     ║")
    print("╚════════════════════════════════════════════════════╝")
    
    simulator = AttackSimulator()
    
    while True:
        print("\n" + "="*50)
        print("Opciones de Prueba:")
        print("="*50)
        print("1. Probar conexión con Discord")
        print("2. Simular ataque DDoS completo")
        print("3. Simular ataque SSH")
        print("4. Simular bloqueo de IP")
        print("5. Enviar todas las notificaciones")
        print("6. Salir")
        print("="*50)
        
        try:
            choice = input("\nSelecciona una opción (1-6): ").strip()
            
            if choice == '1':
                simulator.test_discord_connection()
            
            elif choice == '2':
                simulator.simulate_ddos_attack()
            
            elif choice == '3':
                simulator.simulate_ssh_attack()
            
            elif choice == '4':
                simulator.simulate_ip_block()
            
            elif choice == '5':
                print("\n=== Enviando Todas las Notificaciones ===\n")
                simulator.test_discord_connection()
                time.sleep(2)
                simulator.simulate_ddos_attack()
                time.sleep(2)
                simulator.simulate_ssh_attack()
                time.sleep(2)
                simulator.simulate_ip_block()
            
            elif choice == '6':
                print("\n👋 ¡Hasta luego!")
                break
            
            else:
                print("❌ Opción inválida")
        
        except KeyboardInterrupt:
            print("\n\n👋 Interrumpido por el usuario")
            break
        except Exception as e:
            print(f"\n❌ Error: {e}")
    
    print()


if __name__ == '__main__':
    main()
