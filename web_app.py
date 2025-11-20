#!/usr/bin/env python3
"""
SIP ALG Checker Web Interface
A Flask-based web application for the SIP ALG Checker
"""

from flask import Flask, render_template, jsonify, request
from sip_alg_checker import SIPALGChecker, NetworkMonitor
import time

app = Flask(__name__)


@app.route('/')
def index():
    """Render the main dashboard"""
    return render_template('index.html')


@app.route('/api/check_alg', methods=['POST'])
def check_alg():
    """API endpoint to check for SIP ALG"""
    try:
        checker = SIPALGChecker()
        results = checker.check_sip_alg_via_nat()
        
        # Format the response for the web interface
        response = {
            'success': True,
            'status': results['sip_alg_detected'],
            'recommendation': results['recommendation'],
            'details': {
                'local_ip': results['local_ip'],
                'timestamp': results['timestamp'],
                'checks': results['checks_performed']
            }
        }
        return jsonify(response)
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
        target_ip = data.get('target_ip', '8.8.8.8')
        duration = int(data.get('duration', 10))
        
        # Limit duration to prevent long-running requests
        if duration > 60:
            duration = 60
        
        # Create monitor and perform measurements
        monitor = NetworkMonitor(target_host=target_ip)
        
        # Perform measurements over the duration
        for _ in range(duration):
            monitor.measure_once()
            time.sleep(1)
        
        # Get final statistics
        stats = monitor.get_stats()
        
        response = {
            'success': True,
            'stats': stats
        }
        return jsonify(response)
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


if __name__ == '__main__':
    print("=" * 60)
    print("SIP ALG Checker Web Interface")
    print("=" * 60)
    print("Starting server on http://0.0.0.0:5000")
    print("Press Ctrl+C to stop the server")
    print("=" * 60)
    app.run(host='0.0.0.0', port=5000, debug=True)
