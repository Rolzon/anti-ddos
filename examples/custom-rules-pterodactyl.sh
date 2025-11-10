#!/bin/bash
# Custom firewall rules for Pterodactyl and Database protection
# Place this file in /etc/antiddos/custom-rules.sh

echo "Applying custom Pterodactyl and Database protection rules..."

# ============================================
# DATABASE PROTECTION (MySQL/MariaDB)
# ============================================

# Limit connections per IP to MySQL (port 3306)
iptables -I ANTIDDOS -p tcp --dport 3306 -m connlimit --connlimit-above 10 -j REJECT --reject-with tcp-reset

# Rate limit new MySQL connections
iptables -I ANTIDDOS -p tcp --dport 3306 --syn -m limit --limit 10/s --limit-burst 20 -j ACCEPT
iptables -I ANTIDDOS -p tcp --dport 3306 --syn -j DROP

# ============================================
# POSTGRESQL PROTECTION (if using PostgreSQL)
# ============================================

# Limit connections per IP to PostgreSQL (port 5432)
iptables -I ANTIDDOS -p tcp --dport 5432 -m connlimit --connlimit-above 10 -j REJECT --reject-with tcp-reset

# Rate limit new PostgreSQL connections
iptables -I ANTIDDOS -p tcp --dport 5432 --syn -m limit --limit 10/s --limit-burst 20 -j ACCEPT
iptables -I ANTIDDOS -p tcp --dport 5432 --syn -j DROP

# ============================================
# PTERODACTYL PANEL PROTECTION
# ============================================

# Rate limit HTTP traffic (port 80)
iptables -I ANTIDDOS -p tcp --dport 80 -m limit --limit 100/s --limit-burst 200 -j ACCEPT
iptables -I ANTIDDOS -p tcp --dport 80 -j DROP

# Rate limit HTTPS traffic (port 443)
iptables -I ANTIDDOS -p tcp --dport 443 -m limit --limit 100/s --limit-burst 200 -j ACCEPT
iptables -I ANTIDDOS -p tcp --dport 443 -j DROP

# Connection limit for HTTP
iptables -I ANTIDDOS -p tcp --dport 80 -m connlimit --connlimit-above 50 -j REJECT --reject-with tcp-reset

# Connection limit for HTTPS
iptables -I ANTIDDOS -p tcp --dport 443 -m connlimit --connlimit-above 50 -j REJECT --reject-with tcp-reset

# ============================================
# PTERODACTYL WINGS PROTECTION
# ============================================

# Protect Wings API (default port 8080)
iptables -I ANTIDDOS -p tcp --dport 8080 -m connlimit --connlimit-above 30 -j REJECT --reject-with tcp-reset

# Rate limit Wings API
iptables -I ANTIDDOS -p tcp --dport 8080 -m limit --limit 50/s --limit-burst 100 -j ACCEPT
iptables -I ANTIDDOS -p tcp --dport 8080 -j DROP

# Protect SFTP (if enabled, default port 2022)
iptables -I ANTIDDOS -p tcp --dport 2022 -m connlimit --connlimit-above 10 -j REJECT --reject-with tcp-reset

# ============================================
# REDIS PROTECTION (if using Redis)
# ============================================

# Limit connections per IP to Redis (port 6379)
iptables -I ANTIDDOS -p tcp --dport 6379 -m connlimit --connlimit-above 20 -j REJECT --reject-with tcp-reset

# Rate limit Redis connections
iptables -I ANTIDDOS -p tcp --dport 6379 --syn -m limit --limit 20/s -j ACCEPT
iptables -I ANTIDDOS -p tcp --dport 6379 --syn -j DROP

# ============================================
# GAME SERVER PROTECTION (Examples)
# ============================================

# Minecraft (port 25565)
iptables -I ANTIDDOS -p tcp --dport 25565 -m limit --limit 50/s --limit-burst 100 -j ACCEPT
iptables -I ANTIDDOS -p udp --dport 25565 -m limit --limit 100/s --limit-burst 200 -j ACCEPT

# FiveM (port 30120)
iptables -I ANTIDDOS -p tcp --dport 30120 -m limit --limit 50/s --limit-burst 100 -j ACCEPT
iptables -I ANTIDDOS -p udp --dport 30120 -m limit --limit 100/s --limit-burst 200 -j ACCEPT

# Rust (port 28015)
iptables -I ANTIDDOS -p tcp --dport 28015 -m limit --limit 50/s --limit-burst 100 -j ACCEPT
iptables -I ANTIDDOS -p udp --dport 28015 -m limit --limit 100/s --limit-burst 200 -j ACCEPT

# ARK (port 7777-7778)
iptables -I ANTIDDOS -p udp --dport 7777:7778 -m limit --limit 100/s --limit-burst 200 -j ACCEPT

# CS:GO (port 27015)
iptables -I ANTIDDOS -p tcp --dport 27015 -m limit --limit 50/s --limit-burst 100 -j ACCEPT
iptables -I ANTIDDOS -p udp --dport 27015 -m limit --limit 100/s --limit-burst 200 -j ACCEPT

# ============================================
# ADDITIONAL PROTECTIONS
# ============================================

# Protect DNS (if running DNS server)
iptables -I ANTIDDOS -p udp --dport 53 -m limit --limit 50/s --limit-burst 100 -j ACCEPT
iptables -I ANTIDDOS -p udp --dport 53 -j DROP

# Protect NTP (if running NTP server)
iptables -I ANTIDDOS -p udp --dport 123 -m limit --limit 10/s --limit-burst 20 -j ACCEPT
iptables -I ANTIDDOS -p udp --dport 123 -j DROP

# ============================================
# SAVE RULES
# ============================================

# Save iptables rules
netfilter-persistent save

echo "Custom rules applied successfully!"
