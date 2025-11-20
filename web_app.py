#!/usr/bin/env python3
"""
Flask Web Application for SIP ALG Checker
Provides a user-friendly web interface for checking SIP ALG and monitoring network quality
"""

from flask import Flask, render_template, jsonify, request
import time
import re
from sip_alg_checker import SIPALGChecker, NetworkMonitor

app = Flask(__name__)


def validate_host(host):
    """Validate if the host is a valid IP address or hostname"""
    # IP address pattern
    ip_pattern = r'^(\d{1,3}\.){3}\d{1,3}$'
    # Hostname pattern (simplified)
    hostname_pattern = r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$'
    
    if re.match(ip_pattern, host):
        # Validate IP address octets
        octets = host.split('.')
        return all(0 <= int(octet) <= 255 for octet in octets)
    
    return bool(re.match(hostname_pattern, host))


@app.route('/')
def index():
    """Serve the main dashboard"""
    return render_template('index.html')


@app.route('/api/check-alg', methods=['GET'])
def check_alg():
    """API endpoint to check SIP ALG status"""
    try:
        checker = SIPALGChecker()
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
    """API endpoint to monitor network quality"""
    try:
        data = request.get_json()
        target_host = data.get('target', '8.8.8.8')
        duration = int(data.get('duration', 10))
        interval = float(data.get('interval', 1))
        
        # Validate inputs
        if not validate_host(target_host):
            return jsonify({
                'success': False,
                'error': 'Invalid target host. Please provide a valid IP address or hostname.'
            }), 400
        
        if duration < 1 or duration > 300:
            return jsonify({
                'success': False,
                'error': 'Duration must be between 1 and 300 seconds'
            }), 400
            
        if interval < 0.5 or interval > 10:
            return jsonify({
                'success': False,
                'error': 'Interval must be between 0.5 and 10 seconds'
            }), 400
        
        # Create monitor and collect stats
        monitor = NetworkMonitor(target_host)
        start_time = time.time()
        
        while (time.time() - start_time) < duration:
            monitor.measure_once()
            time.sleep(interval)
        
        # Get final statistics
        stats = monitor.get_stats()
        
        return jsonify({
            'success': True,
            'data': stats
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


if __name__ == '__main__':
    import os
    # Use debug mode only in development
    debug_mode = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'
    app.run(debug=debug_mode, host='0.0.0.0', port=5000)
