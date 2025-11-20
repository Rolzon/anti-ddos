"""
Service-level monitoring utilities for Anti-DDoS
"""

from dataclasses import dataclass, field
from collections import defaultdict, deque
from typing import Dict, List, Optional, Tuple
import logging
import time
import subprocess

import psutil
# requests is optional; guard usage for environments sin acceso
try:
    import requests
except ImportError:  # pragma: no cover - optional dependency
    requests = None


@dataclass
class ServiceInfo:
    """Metadata for a monitored service (e.g., Minecraft server)"""

    id: str
    name: str
    port: Optional[int] = None
    protocol: str = "tcp"
    interface: Optional[str] = None
    threshold_mbps: float = 500.0
    threshold_pps: int = 80000
    rate_limit_pps: Optional[int] = None

    @property
    def display_name(self) -> str:
        return self.name or self.id


@dataclass
class ServiceStats:
    """Aggregated traffic stats for a service"""

    service: ServiceInfo
    mbps_in: float
    mbps_out: float
    pps_in: int
    pps_out: int
    connections: int = 0
    top_attackers: List[Tuple[str, int]] = field(default_factory=list)

    @property
    def total_mbps(self) -> float:
        return self.mbps_in + self.mbps_out

    @property
    def total_pps(self) -> int:
        return self.pps_in + self.pps_out


class ServiceRegistry:
    """Loads service definitions from configuration"""

    def __init__(self, config):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self._services: Optional[List[ServiceInfo]] = None
        self.auto_cfg = self.config.get('services.auto_discovery', {}) or {}
        self.refresh_interval = int(self.auto_cfg.get('refresh_seconds', 60))
        self.last_refresh = 0.0

    def get_services(self) -> List[ServiceInfo]:
        should_refresh = (
            self._services is None or
            (
                self.auto_cfg.get('enabled') and
                (time.time() - self.last_refresh) >= self.refresh_interval
            )
        )

        if should_refresh:
            self._services = self._load_services()
            self.last_refresh = time.time()

        return self._services or []

    def _load_services(self) -> List[ServiceInfo]:
        services = self._load_from_config()
        if self.auto_cfg.get('enabled'):
            discovered = self._discover_services()
            services.extend(discovered)
            services = self._dedupe_services(services)
        return services

    def _load_from_config(self) -> List[ServiceInfo]:
        services_cfg = self.config.get('services.definitions', []) or []
        defaults = self._service_defaults()
        services: List[ServiceInfo] = []
        for entry in services_cfg:
            service = self._build_service_from_entry(entry, defaults)
            if service:
                services.append(service)
        return services

    def _service_defaults(self) -> Dict[str, float]:
        return {
            'threshold_mbps': float(self.config.get('services.default_threshold_mbps', 500)),
            'threshold_pps': int(self.config.get('services.default_threshold_pps', 80000)),
            'rate_limit_pps': int(self.config.get('services.auto_rate_limit.limit_pps', 20000)),
        }

    def _build_service_from_entry(self, entry: Dict, defaults: Dict[str, float]) -> Optional[ServiceInfo]:
        service_id = entry.get('id')
        if not service_id:
            self.logger.warning("Skipping service entry without 'id'")
            return None

        name = entry.get('name', service_id)
        interface = entry.get('interface')
        port = entry.get('port')
        protocol = (entry.get('protocol') or 'tcp').lower()
        threshold_mbps = float(entry.get('threshold_mbps', defaults['threshold_mbps']))
        threshold_pps = int(entry.get('threshold_pps', defaults['threshold_pps']))
        rate_limit_pps = entry.get('rate_limit_pps')
        if rate_limit_pps is None:
            rate_limit_pps = defaults['rate_limit_pps']

        return ServiceInfo(
            id=service_id,
            name=name,
            interface=interface,
            port=port,
            protocol=protocol,
            threshold_mbps=threshold_mbps,
            threshold_pps=threshold_pps,
            rate_limit_pps=rate_limit_pps,
        )

    def _discover_services(self) -> List[ServiceInfo]:
        mode = (self.auto_cfg.get('mode') or 'wings').lower()
        if mode == 'docker':
            return self._discover_from_docker()
        return self._discover_from_wings()

    def _discover_from_wings(self) -> List[ServiceInfo]:
        if not requests:
            self.logger.warning("requests no disponible, se omite auto-discovery Wings")
            return []

        wings_cfg = self.auto_cfg.get('wings', {}) or {}
        api_url = (wings_cfg.get('api_url') or 'http://127.0.0.1:8080').rstrip('/')
        token = wings_cfg.get('token')
        if not token:
            self.logger.debug("Wings auto-discovery skipped: token missing")
            return []

        url = f"{api_url}/api/servers"
        headers = {
            'Authorization': f"Bearer {token}",
            'Accept': 'application/json'
        }

        try:
            response = requests.get(url, headers=headers, timeout=5)
            response.raise_for_status()
            payload = response.json()
        except Exception as exc:  # pragma: no cover - depends on network
            self.logger.warning(f"Wings auto-discovery failed: {exc}")
            return []

        data = payload.get('data') or []
        defaults = self._service_defaults()
        services: List[ServiceInfo] = []

        for entry in data:
            attributes = entry.get('attributes', {})
            relationships = entry.get('relationships', {})

            server_id = (
                attributes.get('uuidShort') or
                attributes.get('uuid') or
                attributes.get('identifier') or
                attributes.get('id')
            )

            if not server_id:
                continue

            allocations = []
            if 'allocations' in relationships:
                allocations = relationships['allocations'].get('data', [])
            if not allocations:
                allocations = attributes.get('allocations', [])

            if not allocations:
                continue

            name = attributes.get('name') or f"Wings {server_id}"
            protocol = (attributes.get('protocol') or 'tcp').lower()

            for allocation in allocations:
                alloc_attrs = allocation.get('attributes', {})
                port = alloc_attrs.get('port') or allocation.get('port')
                if not port:
                    continue

                service = ServiceInfo(
                    id=f"wings-{server_id}-{port}",
                    name=name,
                    port=int(port),
                    protocol=protocol,
                    threshold_mbps=defaults['threshold_mbps'],
                    threshold_pps=defaults['threshold_pps'],
                    rate_limit_pps=defaults['rate_limit_pps'],
                )
                services.append(service)

        if services:
            self.logger.info(f"Auto-descubiertos {len(services)} servicios desde Wings")
        return services

    def _discover_from_docker(self) -> List[ServiceInfo]:
        docker_cfg = self.auto_cfg.get('docker', {}) or {}
        defaults = self._service_defaults()
        services: List[ServiceInfo] = []

        try:
            result = subprocess.run(
                ['docker', 'ps', '--format', '{{.ID}} {{.Names}} {{.Ports}}'],
                capture_output=True,
                text=True,
                check=False
            )
        except FileNotFoundError:
            self.logger.warning("Docker CLI no encontrado, se omite auto-discovery")
            return services

        if result.returncode != 0:
            self.logger.warning(f"docker ps falló: {result.stderr.strip()}")
            return services

        for line in result.stdout.strip().splitlines():
            parts = line.split(' ', 2)
            if len(parts) < 3:
                continue
            container_id, name, ports_field = parts
            if not ports_field or ports_field == '<none>':
                continue

            mappings = [p.strip() for p in ports_field.split(',') if p.strip()]
            for mapping in mappings:
                if '->' not in mapping:
                    continue
                host_part, container_part = mapping.split('->', 1)
                host_port = self._extract_port(host_part)
                container_port = self._extract_port(container_part)
                protocol = 'tcp'
                if '/' in container_part:
                    protocol = container_part.split('/')[-1].lower()

                port_value = host_port or container_port
                if not port_value:
                    continue

                service = ServiceInfo(
                    id=f"docker-{container_id[:12]}-{port_value}",
                    name=name,
                    port=port_value,
                    protocol=protocol,
                    threshold_mbps=defaults['threshold_mbps'],
                    threshold_pps=defaults['threshold_pps'],
                    rate_limit_pps=defaults['rate_limit_pps'],
                )
                services.append(service)

        if services:
            self.logger.info(f"Auto-descubiertos {len(services)} servicios desde Docker")
        return services

    def _extract_port(self, fragment: str) -> Optional[int]:
        if not fragment:
            return None
        if ':' in fragment:
            fragment = fragment.split(':')[-1]
        fragment = fragment.split('/')[0]
        if fragment.isdigit():
            return int(fragment)
        return None

    def _dedupe_services(self, services: List[ServiceInfo]) -> List[ServiceInfo]:
        unique: Dict[str, ServiceInfo] = {}
        for service in services:
            unique[service.id] = service
        return list(unique.values())


class ServiceTrafficMonitor:
    """Calculates Mbps/PPS per service interface"""

    def __init__(self, window_seconds: int = 10):
        self.window_seconds = max(1, window_seconds)
        self.logger = logging.getLogger(__name__)
        self.last_stats: Dict[str, Dict[str, float]] = {}
        self.samples: Dict[str, deque] = defaultdict(lambda: deque(maxlen=self.window_seconds))

    def collect_stats(self, services: List[ServiceInfo]) -> Dict[str, ServiceStats]:
        if not services:
            return {}

        pernic_stats = psutil.net_io_counters(pernic=True)
        now = time.time()
        results: Dict[str, ServiceStats] = {}

        port_map = self._build_port_map(services)
        connections_snapshot = self._collect_connection_data(port_map)

        for service in services:
            interface = service.interface
            if not interface:
                continue

            iface_stats = pernic_stats.get(interface)
            if not iface_stats:
                continue

            last = self.last_stats.get(interface)
            self.last_stats[interface] = {
                'time': now,
                'bytes_sent': iface_stats.bytes_sent,
                'bytes_recv': iface_stats.bytes_recv,
                'packets_sent': iface_stats.packets_sent,
                'packets_recv': iface_stats.packets_recv,
            }

            if not last:
                continue  # Need at least two samples to compute delta

            time_delta = now - last['time']
            if time_delta <= 0:
                continue

            bytes_sent_delta = iface_stats.bytes_sent - last['bytes_sent']
            bytes_recv_delta = iface_stats.bytes_recv - last['bytes_recv']
            packets_sent_delta = iface_stats.packets_sent - last['packets_sent']
            packets_recv_delta = iface_stats.packets_recv - last['packets_recv']

            mbps_out = max(0.0, (bytes_sent_delta * 8) / (time_delta * 1_000_000))
            mbps_in = max(0.0, (bytes_recv_delta * 8) / (time_delta * 1_000_000))
            pps_out = max(0, int(packets_sent_delta / time_delta))
            pps_in = max(0, int(packets_recv_delta / time_delta))

            iface_samples = self.samples[interface]
            iface_samples.append({
                'mbps_in': mbps_in,
                'mbps_out': mbps_out,
                'pps_in': pps_in,
                'pps_out': pps_out,
            })

            avg_mbps_in = sum(sample['mbps_in'] for sample in iface_samples) / len(iface_samples)
            avg_mbps_out = sum(sample['mbps_out'] for sample in iface_samples) / len(iface_samples)
            avg_pps_in = int(sum(sample['pps_in'] for sample in iface_samples) / len(iface_samples))
            avg_pps_out = int(sum(sample['pps_out'] for sample in iface_samples) / len(iface_samples))

            conn_info = connections_snapshot.get(service.id, {})
            stats = ServiceStats(
                service=service,
                mbps_in=avg_mbps_in,
                mbps_out=avg_mbps_out,
                pps_in=avg_pps_in,
                pps_out=avg_pps_out,
                connections=conn_info.get('connections', 0),
                top_attackers=conn_info.get('top_attackers', []),
            )
            results[service.id] = stats

        return results

    def _build_port_map(self, services: List[ServiceInfo]) -> Dict[int, List[str]]:
        port_map: Dict[int, List[str]] = defaultdict(list)
        for service in services:
            if service.port:
                port_map[int(service.port)].append(service.id)
        return port_map

    def _collect_connection_data(self, port_map: Dict[int, List[str]]) -> Dict[str, Dict[str, object]]:
        results: Dict[str, Dict[str, object]] = {}
        if not port_map:
            return results

        try:
            connections = psutil.net_connections(kind='inet')
        except Exception as exc:  # pragma: no cover - depends on platform permissions
            self.logger.debug(f"Unable to collect connection data: {exc}")
            return results

        connection_counts: Dict[str, int] = defaultdict(int)
        attacker_counts: Dict[str, Dict[str, int]] = defaultdict(lambda: defaultdict(int))

        for conn in connections:
            if not conn.laddr:
                continue
            service_ids = port_map.get(conn.laddr.port)
            if not service_ids:
                continue

            remote_ip: Optional[str] = None
            if conn.raddr:
                if isinstance(conn.raddr, tuple):
                    remote_ip = conn.raddr[0]
                else:
                    remote_ip = getattr(conn.raddr, 'ip', None)

            for service_id in service_ids:
                connection_counts[service_id] += 1
                if remote_ip:
                    attacker_counts[service_id][remote_ip] += 1

        for service_id, count in connection_counts.items():
            ip_counts = attacker_counts.get(service_id, {})
            top_attackers = sorted(
                ip_counts.items(),
                key=lambda item: item[1],
                reverse=True,
            )[:5]
            results[service_id] = {
                'connections': count,
                'top_attackers': top_attackers,
            }

        return results
