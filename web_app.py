#!/usr/bin/env python3
"""
Web Interface for SIP ALG Checker
Provides a user-friendly web dashboard for SIP ALG checking and network monitoring
"""

from flask import Flask, render_template, jsonify, request
import time
from sip_alg_checker import SIPALGChecker, NetworkMonitor

app = Flask(__name__)

@app.route('/')
def dashboard():
    """Render the main dashboard"""
    return render_template('index.html')

@app.route('/api/check_alg', methods=['POST'])
def check_alg():
    """Run SIP ALG check and return results as JSON"""
    try:
        # Get optional local_ip from request
        data = request.get_json() or {}
        local_ip = data.get('local_ip')
        
        checker = SIPALGChecker(local_ip=local_ip)
        results = checker.check_sip_alg_via_nat()
        
        return jsonify({
            'success': True,
            'data': results
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/monitor', methods=['POST'])
def monitor():
    """Run network monitoring and return results as JSON"""
    try:
        data = request.get_json()
        
        # Validate required parameters
        if not data or 'host' not in data:
            return jsonify({
                'success': False,
                'error': 'Host parameter is required'
            }), 400
        
        host = data['host']
        duration = int(data.get('duration', 30))  # Default 30 seconds
        count = int(data.get('count', duration))  # Default to duration
        
        # Limit duration and count for web requests
        duration = min(duration, 300)  # Max 5 minutes
        count = min(count, 300)  # Max 300 measurements
        
        # Create monitor and run measurements
        monitor = NetworkMonitor(target_host=host, sample_size=count)
        
        measurements = []
        start_time = time.time()
        
        # Run measurements for specified duration or count
        for i in range(count):
            if (time.time() - start_time) >= duration:
                break
                
            monitor.measure_once()
            
            # Collect measurement data periodically
            if i % 5 == 0 or i == count - 1:
                stats = monitor.get_stats()
                measurements.append(stats)
            
            # Small delay between measurements
            if i < count - 1:
                time.sleep(max(0.5, duration / count))
        
        # Get final statistics
        final_stats = monitor.get_stats()
        
        return jsonify({
            'success': True,
            'data': {
                'summary': final_stats,
                'measurements': measurements
            }
        })
    except ValueError as e:
        return jsonify({
            'success': False,
            'error': f'Invalid parameter: {str(e)}'
        }), 400
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
