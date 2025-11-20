#!/usr/bin/env python3
"""
Flask Web Application for SIP ALG Checker
Provides a web interface to check SIP ALG status and monitor network quality.
"""

from flask import Flask, render_template, jsonify, request
from sip_alg_checker import SIPALGChecker, NetworkMonitor
import time

app = Flask(__name__)


@app.route('/')
def index():
    """Render the main dashboard"""
    return render_template('index.html')


@app.route('/api/check_alg', methods=['GET'])
def check_alg():
    """API endpoint to run the ALG check and return JSON results"""
    try:
        # Get optional local_ip parameter
        local_ip = request.args.get('local_ip', None)
        
        # Create checker and run check
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
    """API endpoint to run the network monitor and return JSON results"""
    try:
        # Get parameters from request
        data = request.get_json() or {}
        target_host = data.get('target_host', '8.8.8.8')
        duration = min(int(data.get('duration', 10)), 30)  # Max 30 seconds for web
        
        # Create monitor
        monitor_obj = NetworkMonitor(target_host=target_host, sample_size=duration)
        
        # Perform measurements with error handling for each ping
        successful_pings = 0
        for _ in range(duration):
            try:
                if monitor_obj.measure_once():
                    successful_pings += 1
            except PermissionError:
                # ping3 requires root privileges, fall back will be used automatically
                pass
            except Exception:
                # Other errors, continue with next measurement
                pass
            time.sleep(1)
        
        # Get statistics
        stats = monitor_obj.get_stats()
        
        # Add a note if running without proper permissions
        if successful_pings == 0 and monitor_obj.packets_sent > 0:
            stats['note'] = 'Running with limited permissions. Some measurements may use fallback methods.'
        
        return jsonify({
            'success': True,
            'data': stats
        })
    except PermissionError as e:
        return jsonify({
            'success': False,
            'error': 'Permission denied. The network monitor requires elevated privileges to use ICMP ping. Try running with sudo or use the socket-based fallback.'
        }), 500
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


if __name__ == '__main__':
    # Run the Flask app
    # In production, use a proper WSGI server like gunicorn
    app.run(host='0.0.0.0', port=5000, debug=True)
