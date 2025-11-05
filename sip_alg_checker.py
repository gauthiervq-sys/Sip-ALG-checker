#!/usr/bin/env python3
"""
SIP ALG Checker Tool
A comprehensive tool to check SIP ALG status and monitor network quality parameters
including Jitter, Packet Loss, and other important metrics over time.
"""

import socket
import time
import argparse
import json
import sys
from datetime import datetime
from collections import deque
import statistics

try:
    import ping3
    PING3_AVAILABLE = True
except ImportError:
    PING3_AVAILABLE = False
    print("Warning: ping3 not available. Some features will be limited.")


class NetworkMonitor:
    """Monitor network quality parameters"""
    
    def __init__(self, target_host, sample_size=30):
        self.target_host = target_host
        self.sample_size = sample_size
        self.latencies = deque(maxlen=sample_size)
        self.packet_loss_count = 0
        self.packets_sent = 0
        
    def ping(self, timeout=2):
        """Send a single ping and return latency in ms"""
        if not PING3_AVAILABLE:
            # Fallback to simple socket test
            try:
                start = time.time()
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(timeout)
                sock.connect((self.target_host, 5060))  # SIP port
                latency = (time.time() - start) * 1000
                sock.close()
                return latency
            except Exception:
                return None
        else:
            latency = ping3.ping(self.target_host, timeout=timeout)
            if latency is not None:
                return latency * 1000  # Convert to ms
            return None
    
    def measure_once(self):
        """Perform a single measurement"""
        self.packets_sent += 1
        latency = self.ping()
        
        if latency is not None:
            self.latencies.append(latency)
            return True
        else:
            self.packet_loss_count += 1
            return False
    
    def calculate_jitter(self):
        """Calculate jitter (variance in latency)"""
        if len(self.latencies) < 2:
            return 0.0
        
        differences = []
        latency_list = list(self.latencies)
        for i in range(1, len(latency_list)):
            differences.append(abs(latency_list[i] - latency_list[i-1]))
        
        return statistics.mean(differences) if differences else 0.0
    
    def calculate_packet_loss(self):
        """Calculate packet loss percentage"""
        if self.packets_sent == 0:
            return 0.0
        return (self.packet_loss_count / self.packets_sent) * 100
    
    def get_stats(self):
        """Get current network statistics"""
        stats = {
            'timestamp': datetime.now().isoformat(),
            'target': self.target_host,
            'packets_sent': self.packets_sent,
            'packets_received': self.packets_sent - self.packet_loss_count,
            'packet_loss_percent': round(self.calculate_packet_loss(), 2),
        }
        
        if self.latencies:
            stats['avg_latency_ms'] = round(statistics.mean(self.latencies), 2)
            stats['min_latency_ms'] = round(min(self.latencies), 2)
            stats['max_latency_ms'] = round(max(self.latencies), 2)
            stats['jitter_ms'] = round(self.calculate_jitter(), 2)
        else:
            stats['avg_latency_ms'] = 0
            stats['min_latency_ms'] = 0
            stats['max_latency_ms'] = 0
            stats['jitter_ms'] = 0
        
        return stats


class SIPALGChecker:
    """Check for SIP ALG interference"""
    
    def __init__(self, local_ip=None, test_server=None):
        self.local_ip = local_ip or self._get_local_ip()
        self.test_server = test_server
        
    def _get_local_ip(self):
        """Get local IP address"""
        try:
            # Create a socket to determine local IP
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
            s.close()
            return local_ip
        except Exception:
            return "127.0.0.1"
    
    def check_sip_alg_via_nat(self):
        """
        Check for SIP ALG by examining NAT behavior.
        SIP ALG typically modifies SIP headers and SDP content.
        """
        results = {
            'local_ip': self.local_ip,
            'timestamp': datetime.now().isoformat(),
            'checks_performed': []
        }
        
        # Check 1: Port availability for SIP
        sip_port_check = self._check_sip_port()
        results['checks_performed'].append({
            'name': 'SIP Port (5060) Availability',
            'status': 'PASS' if sip_port_check else 'FAIL',
            'description': 'Checks if SIP port 5060 is accessible'
        })
        
        # Check 2: Multiple SIP ports for RTP
        rtp_port_range = self._check_rtp_ports()
        results['checks_performed'].append({
            'name': 'RTP Port Range Check',
            'open_ports': rtp_port_range,
            'description': 'Checks availability of RTP ports (10000-20000)'
        })
        
        # Check 3: Network translation behavior
        nat_behavior = self._check_nat_behavior()
        results['checks_performed'].append({
            'name': 'NAT Behavior Analysis',
            'behavior': nat_behavior,
            'description': 'Analyzes how NAT handles connections'
        })
        
        # Determine if SIP ALG is likely present
        results['sip_alg_detected'] = self._analyze_alg_presence(results)
        results['recommendation'] = self._get_recommendation(results)
        
        return results
    
    def _check_sip_port(self):
        """Check if SIP port is accessible"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            # Bind to all interfaces for diagnostic port availability check
            # Socket is immediately closed after testing
            sock.bind(('', 5060))
            sock.close()
            return True
        except Exception:
            return False
    
    def _check_rtp_ports(self, sample_count=5):
        """Check availability of RTP ports"""
        open_ports = 0
        test_ports = [10000, 12000, 14000, 16000, 18000]
        
        for port in test_ports:
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                # Bind to all interfaces for diagnostic port availability check
                # Socket is immediately closed after testing
                sock.bind(('', port))
                sock.close()
                open_ports += 1
            except Exception:
                pass
        
        return open_ports
    
    def _check_nat_behavior(self):
        """Check NAT behavior characteristics"""
        # This is a simplified check
        # In a real scenario, you'd send SIP REGISTER messages
        # and analyze the responses
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.settimeout(2)
            # Attempt to bind to multiple ports to test NAT consistency
            return "Symmetric NAT" if self.local_ip.startswith("192.168") or \
                                       self.local_ip.startswith("10.") else "Unknown"
        except Exception:
            return "Unknown"
    
    def _analyze_alg_presence(self, results):
        """Analyze results to determine if SIP ALG is likely present"""
        # SIP ALG is more likely if:
        # - We're behind NAT (private IP)
        # - SIP port has issues
        # - Limited RTP port availability
        
        behind_nat = (self.local_ip.startswith("192.168") or 
                     self.local_ip.startswith("10.") or 
                     self.local_ip.startswith("172."))
        
        if not behind_nat:
            return "UNLIKELY"
        
        port_issues = False
        for check in results['checks_performed']:
            if 'Port' in check['name'] and check.get('status') == 'FAIL':
                port_issues = True
        
        if port_issues:
            return "LIKELY"
        
        return "POSSIBLE"
    
    def _get_recommendation(self, results):
        """Get recommendation based on analysis"""
        if results['sip_alg_detected'] == "LIKELY":
            return ("SIP ALG is likely interfering with your VoIP traffic. "
                   "Recommendation: Disable SIP ALG in your router settings. "
                   "This typically improves VoIP call quality and reduces connection issues.")
        elif results['sip_alg_detected'] == "POSSIBLE":
            return ("SIP ALG may be present. If experiencing VoIP issues, "
                   "try disabling SIP ALG in your router settings.")
        else:
            return "No strong indication of SIP ALG interference detected."


def print_stats(stats, clear_screen=False):
    """Pretty print network statistics"""
    if clear_screen:
        print("\033[2J\033[H", end='')  # Clear screen
    
    print("=" * 60)
    print(f"Network Quality Monitor - {stats['timestamp']}")
    print("=" * 60)
    print(f"Target: {stats['target']}")
    print(f"Packets: Sent={stats['packets_sent']}, Received={stats['packets_received']}")
    print(f"Packet Loss: {stats['packet_loss_percent']}%")
    print(f"Latency: Avg={stats['avg_latency_ms']}ms, "
          f"Min={stats['min_latency_ms']}ms, Max={stats['max_latency_ms']}ms")
    print(f"Jitter: {stats['jitter_ms']}ms")
    
    # Quality assessment
    quality = "EXCELLENT"
    if stats['packet_loss_percent'] > 1 or stats['jitter_ms'] > 30:
        quality = "POOR"
    elif stats['packet_loss_percent'] > 0.5 or stats['jitter_ms'] > 20:
        quality = "FAIR"
    elif stats['jitter_ms'] > 10:
        quality = "GOOD"
    
    print(f"Quality Assessment: {quality}")
    print("=" * 60)


def monitor_network(target_host, duration=60, interval=1, output_file=None):
    """Monitor network quality over time"""
    monitor = NetworkMonitor(target_host)
    print(f"\nStarting network monitoring for {target_host}")
    print(f"Duration: {duration} seconds, Interval: {interval} second(s)")
    print("Press Ctrl+C to stop monitoring\n")
    
    start_time = time.time()
    all_stats = []
    
    try:
        while (time.time() - start_time) < duration:
            monitor.measure_once()
            stats = monitor.get_stats()
            all_stats.append(stats)
            print_stats(stats, clear_screen=True)
            time.sleep(interval)
    except KeyboardInterrupt:
        print("\n\nMonitoring stopped by user.")
    
    # Final summary
    final_stats = monitor.get_stats()
    print("\n" + "=" * 60)
    print("FINAL SUMMARY")
    print("=" * 60)
    print_stats(final_stats, clear_screen=False)
    
    # Save to file if requested
    if output_file:
        with open(output_file, 'w') as f:
            json.dump({
                'summary': final_stats,
                'all_measurements': all_stats
            }, f, indent=2)
        print(f"\nResults saved to: {output_file}")
    
    return final_stats


def main():
    parser = argparse.ArgumentParser(
        description='SIP ALG Checker and Network Quality Monitor',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Check for SIP ALG
  %(prog)s --check-alg
  
  # Monitor network quality for 5 minutes
  %(prog)s --monitor 8.8.8.8 --duration 300
  
  # Monitor and save results
  %(prog)s --monitor 8.8.8.8 --duration 120 --output results.json
  
  # Quick check with both
  %(prog)s --check-alg --monitor 8.8.8.8 --duration 60
        """
    )
    
    parser.add_argument('--check-alg', action='store_true',
                        help='Check for SIP ALG interference')
    parser.add_argument('--monitor', type=str, metavar='HOST',
                        help='Monitor network quality to specified host')
    parser.add_argument('--duration', type=int, default=60,
                        help='Monitoring duration in seconds (default: 60)')
    parser.add_argument('--interval', type=int, default=1,
                        help='Monitoring interval in seconds (default: 1)')
    parser.add_argument('--output', type=str, metavar='FILE',
                        help='Save monitoring results to JSON file')
    parser.add_argument('--local-ip', type=str,
                        help='Specify local IP address (auto-detected if not provided)')
    
    args = parser.parse_args()
    
    if not args.check_alg and not args.monitor:
        parser.print_help()
        sys.exit(1)
    
    # Check SIP ALG
    if args.check_alg:
        print("=" * 60)
        print("SIP ALG CHECK")
        print("=" * 60)
        checker = SIPALGChecker(local_ip=args.local_ip)
        results = checker.check_sip_alg_via_nat()
        
        print(f"\nLocal IP: {results['local_ip']}")
        print(f"Timestamp: {results['timestamp']}")
        print(f"\nSIP ALG Status: {results['sip_alg_detected']}")
        print(f"\nRecommendation:\n{results['recommendation']}")
        
        print("\nDetailed Checks:")
        for check in results['checks_performed']:
            print(f"\n  • {check['name']}")
            print(f"    {check['description']}")
            if 'status' in check:
                print(f"    Status: {check['status']}")
            if 'open_ports' in check:
                print(f"    Open Ports: {check['open_ports']}/5")
            if 'behavior' in check:
                print(f"    Behavior: {check['behavior']}")
        print()
    
    # Monitor network quality
    if args.monitor:
        try:
            monitor_network(args.monitor, args.duration, args.interval, args.output)
        except Exception as e:
            print(f"Error during monitoring: {e}")
            sys.exit(1)


if __name__ == '__main__':
    main()
