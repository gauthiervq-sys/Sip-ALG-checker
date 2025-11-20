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
        
        # Validate duration parameter
        try:
            duration = int(data.get('duration', 10))
            duration = min(max(duration, 1), 30)  # Clamp between 1 and 30 seconds
        except (ValueError, TypeError):
            duration = 10  # Default to 10 seconds if invalid
        
        # Create monitor with appropriate sample size (at least duration)
        monitor_obj = NetworkMonitor(target_host=target_host, sample_size=max(duration, 30))
        
        # Perform measurements with error handling for each ping
        for _ in range(duration):
            try:
                monitor_obj.measure_once()
            except PermissionError:
                # ping3 requires root privileges, fall back will be used automatically
                pass
            except Exception:
                # Other errors, continue with next measurement
                pass
            time.sleep(1)
        
        # Get statistics
        stats = monitor_obj.get_stats()
        
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
    # Debug mode is enabled for development only
    import os
    debug_mode = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'
    app.run(host='127.0.0.1', port=5000, debug=debug_mode)
