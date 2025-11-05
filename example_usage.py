#!/usr/bin/env python3
"""
Example usage of SIP ALG Checker as a Python module

This script demonstrates how to use the SIP ALG Checker programmatically
in your own Python applications.
"""

import sys
import json
from sip_alg_checker import SIPALGChecker, NetworkMonitor

def example_sip_alg_check():
    """Example: Check for SIP ALG"""
    print("=" * 60)
    print("EXAMPLE 1: SIP ALG Check")
    print("=" * 60)
    
    checker = SIPALGChecker()
    results = checker.check_sip_alg_via_nat()
    
    print(f"Local IP: {results['local_ip']}")
    print(f"SIP ALG Status: {results['sip_alg_detected']}")
    print(f"Recommendation: {results['recommendation']}")
    print()

def example_network_monitoring():
    """Example: Network quality monitoring"""
    print("=" * 60)
    print("EXAMPLE 2: Network Quality Monitoring")
    print("=" * 60)
    
    # Create a network monitor
    monitor = NetworkMonitor(target_host="8.8.8.8", sample_size=10)
    
    # Perform 5 measurements
    print("Performing 5 measurements...")
    for i in range(5):
        success = monitor.measure_once()
        status = "Success" if success else "Failed"
        print(f"  Measurement {i+1}: {status}")
    
    # Get statistics
    stats = monitor.get_stats()
    
    print("\nResults:")
    print(f"  Packets Sent: {stats['packets_sent']}")
    print(f"  Packets Received: {stats['packets_received']}")
    print(f"  Packet Loss: {stats['packet_loss_percent']}%")
    print(f"  Average Latency: {stats['avg_latency_ms']}ms")
    print(f"  Jitter: {stats['jitter_ms']}ms")
    print()

def example_combined_check():
    """Example: Combined SIP ALG and network monitoring"""
    print("=" * 60)
    print("EXAMPLE 3: Combined Check")
    print("=" * 60)
    
    # Check SIP ALG
    checker = SIPALGChecker()
    alg_results = checker.check_sip_alg_via_nat()
    
    # Monitor network
    monitor = NetworkMonitor(target_host="8.8.8.8")
    for _ in range(3):
        monitor.measure_once()
    
    network_stats = monitor.get_stats()
    
    # Create combined report
    report = {
        "sip_alg": {
            "status": alg_results['sip_alg_detected'],
            "recommendation": alg_results['recommendation']
        },
        "network_quality": {
            "packet_loss": network_stats['packet_loss_percent'],
            "avg_latency": network_stats['avg_latency_ms'],
            "jitter": network_stats['jitter_ms']
        }
    }
    
    print("Combined Report:")
    print(json.dumps(report, indent=2))
    print()

def example_custom_configuration():
    """Example: Using custom configuration"""
    print("=" * 60)
    print("EXAMPLE 4: Custom Configuration")
    print("=" * 60)
    
    # Create monitor with custom sample size
    monitor = NetworkMonitor(
        target_host="8.8.8.8",
        sample_size=5  # Keep only last 5 measurements
    )
    
    print(f"Monitor configured for: {monitor.target_host}")
    print(f"Sample size: {monitor.sample_size}")
    
    # Create SIP checker with specific local IP
    checker = SIPALGChecker(local_ip="192.168.1.100")
    print(f"Checker configured with local IP: {checker.local_ip}")
    print()

def main():
    """Run all examples"""
    print("\n" + "=" * 60)
    print("SIP ALG CHECKER - USAGE EXAMPLES")
    print("=" * 60 + "\n")
    
    try:
        # Run examples
        example_sip_alg_check()
        example_network_monitoring()
        example_combined_check()
        example_custom_configuration()
        
        print("=" * 60)
        print("All examples completed successfully!")
        print("=" * 60)
        
    except Exception as e:
        print(f"Error running examples: {e}", file=sys.stderr)
        return 1
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
