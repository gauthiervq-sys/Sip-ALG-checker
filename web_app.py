#!/usr/bin/env python3
"""
Flask Web Application for SIP ALG Checker
Provides a user-friendly web interface for checking SIP ALG and monitoring network quality
"""

from flask import Flask, render_template, jsonify, request
import time
from sip_alg_checker import SIPALGChecker, NetworkMonitor

app = Flask(__name__)


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
    app.run(debug=True, host='0.0.0.0', port=5000)
